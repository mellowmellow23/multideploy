// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title Remit Token (RMX)
/// @author Julius Macharia
/// @notice ERC-20 reward token for the RemitX cross-border remittance platform.
/// @dev Inherits ERC20, ERC20Burnable, ERC20Permit, and Ownable from OpenZeppelin v5.
///      Users earn RMX when a remittance is processed. Tokens can be burned
///      to claim fee discounts on future transfers.
///
/// Standards referenced:
///   - EIP-20:  https://eips.ethereum.org/EIPS/eip-20
///   - EIP-2612: https://eips.ethereum.org/EIPS/eip-2612  (permit / gasless approvals)
///   - EIP-165: https://eips.ethereum.org/EIPS/eip-165   (interface detection)

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract RemitToken is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    // -------------------------------------------------------------------------
    // Custom errors
    // -------------------------------------------------------------------------
    // Why custom errors instead of require strings?
    // Solidity 0.8.4+ supports custom errors. They cost less gas than string
    // revert messages because the error selector is only 4 bytes, whereas a
    // string is ABI-encoded in full. Auditors and senior devs always look for
    // this pattern — it signals you write production-quality Solidity.
    /// @notice Reverts when a mint would push total supply past MAX_SUPPLY.
    error RemitToken__MaxSupplyExceeded();

    /// @notice Reverts when a zero amount is passed to mint or redeemForDiscount.
    error RemitToken__ZeroAmount();

    /// @notice Reverts when the zero address is passed as a mint recipient.
    error RemitToken__ZeroAddress();

    /// @notice Reverts when renounceOwnership is called.
    /// Ownership renouncement is permanently disabled to protect mint capability.
    error RemitToken__RenounceNotAllowed();

    // -------------------------------------------------------------------------
    // State variables
    // -------------------------------------------------------------------------

    /// @notice Hard cap on total token supply — 50 million RMX (18 decimals).
    /// @dev    Per EIP-20, token amounts are expressed in the smallest unit.
    ///         50_000_000 * 10**18 represents 50 million whole tokens.
    ///         Declared as a constant so it costs no storage slot (cheaper).
    uint256 public constant MAX_SUPPLY = 50_000_000 * 10 ** 18;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a user burns RMX to claim a transfer fee discount.
    /// @param  user   The address that redeemed tokens.
    /// @param  amount The amount of RMX burned (in wei units, 18 decimals).
    /// @dev    Indexed on `user` so frontends and subgraphs can filter by wallet.
    ///         Off-chain indexers (e.g. The Graph) listen for this event to
    ///         trigger the discount on the platform side.
    event DiscountRedeemed(address indexed user, uint256 amount);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Deploys the RemitX Token and sets the initial owner.
    /// @param  initialOwner The address that will receive the owner role.
    ///         In production this would be a multi-sig (e.g. Gnosis Safe).
    ///         In testing / deployment scripts, pass your deployer address.
    /// @dev    Each parent constructor is explicitly called:
    ///         - ERC20: sets name and symbol per EIP-20
    ///         - ERC20Permit: sets the EIP-712 domain name for permit() signatures
    ///         - Ownable: sets the initial owner who can call onlyOwner functions
    ///         ERC20Burnable has no constructor arguments.
    constructor(address initialOwner) ERC20("RemitX Token", "RMX") ERC20Permit("RemitX Token") Ownable(initialOwner) {}

    // -------------------------------------------------------------------------
    // Owner functions
    // -------------------------------------------------------------------------

    /// @notice Mints RMX tokens to a recipient address.
    /// @param  to     The address receiving the newly minted tokens.
    /// @param  amount The number of tokens to mint (in wei units, 18 decimals).
    /// @dev    Only callable by the owner (the transfer agent / platform wallet).
    ///         This simulates the platform rewarding a user after a remittance
    ///         is confirmed on-chain or via a trusted off-chain oracle call.
    ///
    ///         Guards in order:
    ///         1. Zero-address check — we enforce our own invariant explicitly
    ///            rather than relying silently on OZ's internal _mint revert.
    ///            Auditors want to see that YOU control your own logic.
    ///         2. Zero-amount check — minting 0 tokens wastes gas and emits no
    ///            meaningful state change. Reject early.
    ///         3. Supply cap check — totalSupply() + amount must not exceed
    ///            MAX_SUPPLY. Uses custom error for gas efficiency.
    function mint(address to, uint256 amount) public onlyOwner {
        if (to == address(0)) revert RemitToken__ZeroAddress();
        if (amount == 0) revert RemitToken__ZeroAmount();
        if (totalSupply() + amount > MAX_SUPPLY) revert RemitToken__MaxSupplyExceeded();

        // _mint is inherited from OpenZeppelin ERC20.
        // It updates balances, totalSupply, and emits the EIP-20 Transfer event
        // from address(0) to `to` — the standard signal for a mint operation.
        _mint(to, amount);
    }

    /// @notice Disables ownership renouncement permanently.
    /// @dev    Ownable (OZ v5) exposes renounceOwnership() publicly.
    ///         If the owner ever called it by mistake, mint() would be
    ///         permanently locked — no one could ever issue RMX again.
    ///         Overriding and reverting is the standard defensive pattern.
    ///         Reference: https://docs.openzeppelin.com/contracts/5.x/access-control
    function renounceOwnership() public pure override {
        revert RemitToken__RenounceNotAllowed();
    }

    // -------------------------------------------------------------------------
    // User functions
    // -------------------------------------------------------------------------

    /// @notice Burns the caller's RMX tokens to redeem a transfer fee discount.
    /// @param  amount The number of tokens to burn (in wei units, 18 decimals).
    /// @dev    Burning is permanent — tokens are removed from circulation,
    ///         reducing totalSupply. This is intentional: it creates deflationary
    ///         pressure, which is a common DeFi tokenomics pattern.
    ///
    ///         burn() is inherited from ERC20Burnable (OZ). It calls
    ///         _burn(msg.sender, amount) which will revert with
    ///         ERC20InsufficientBalance if the caller holds fewer tokens than
    ///         `amount` — we do not need a separate balance check here.
    ///
    ///         The DiscountRedeemed event is emitted AFTER the burn succeeds.
    ///         This follows the checks-effects-interactions pattern:
    ///         all state changes complete before any external signals go out.
    ///
    ///         Zero-amount guard: burning 0 tokens is a no-op that wastes gas
    ///         and emits a misleading event. Reject it explicitly.
    function redeemForDiscount(uint256 amount) public {
        if (amount == 0) revert RemitToken__ZeroAmount();

        // burn() from ERC20Burnable — handles balance check and state update
        burn(amount);

        emit DiscountRedeemed(msg.sender, amount);
    }
}
