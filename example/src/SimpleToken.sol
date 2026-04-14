// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title SimpleToken
/// @notice Example ERC-20 used to demonstrate MultiDeploy
contract SimpleToken is ERC20, Ownable {
    constructor(address initialOwner)
        ERC20("SimpleToken", "STK")
        Ownable(initialOwner)
    {
        _mint(initialOwner, 1_000_000 * 10 ** 18);
    }
}
