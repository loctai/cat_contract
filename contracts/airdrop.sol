pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CAT_Airdrop is Ownable, Pausable {
    // ONLY ALLOW BUSD
    using SafeERC20 for IERC20;
    IERC20 public BUSD;
    IERC20 public CAT;

    uint256 public amountBUSDClaim;
    uint256 public amountCATClaim;
    uint256 public START_TIME;
    uint256 public constant SECONDS_IN_DAY = 86400;

    mapping(address => uint256) private lastClaimToken;
    mapping(address => uint256) private lastClaimPack;
    event ClaimToken(address user, uint256 time);

    function initialize(
        address _BUSD,
        address _CAT,
        uint256 _TotalBUSD,
        uint256 _TotalCAT
    ) public onlyOwner {
        BUSD = IERC20(_BUSD);
        CAT = IERC20(_CAT);
        amountBUSDClaim = _TotalBUSD;
        amountCATClaim = _TotalCAT;
        BUSD.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
        CAT.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function canClaim(address _user, uint256 _to) public view returns (bool) {
        if (_to < START_TIME) return false;
        uint256 userClaimTo = lastClaimToken[_user] > START_TIME
            ? (lastClaimToken[_user] - START_TIME) / SECONDS_IN_DAY + 1
            : 0;
        uint256 claimTo = (_to - START_TIME) / SECONDS_IN_DAY;

        if (userClaimTo <= claimTo) return true;
        return false;
    }

    function claimToken() public whenNotPaused {
        require(canClaim(msg.sender, block.timestamp), "Error: Can not claim");
        BUSD.transferFrom(address(this), msg.sender, amountBUSDClaim);
        CAT.transferFrom(address(this), msg.sender, amountCATClaim);
        lastClaimToken[msg.sender] = block.timestamp;
        emit ClaimToken(msg.sender, block.timestamp);
    }
}