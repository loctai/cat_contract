// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./nft.sol";
import "./starterpack.sol";

contract ThirtPartyPackage is
    AccessControlEnumerable,
    Ownable,
    ReentrancyGuard
{
    // State
    mapping(address => bool) whiteList;

    bool public whitelistStatus;
    bool public saleStatus;
    bool public limitPackStatus;

    address public feeAddress;

    uint256 public totalPack;
    uint256 public pricePack;
    uint256 public timeStart;
    uint256 public timeEnd;
    uint256 public totalSold;
    uint256 public packIn6hours = 1000;
    uint256 public packIn24hours = 240;
    uint256 public constant secondsFor6hours = 21600;
    uint256 public constant secondsFor1day = 86400;

    // Relation Contract
    using SafeERC20 for IERC20;
    CAT_StarterPack public PackFactory;
    IERC20 public BUSD;

    mapping(address => uint256) private lastClaimToken;
    mapping(address => uint256) private totalBuyOfUser;

    function initialize(
        address _PackFactory,
        address _BUSD,
        address _feeAddress,
        uint256 _pricePack,
        uint256 _timeStart,
        uint256 _timeEnd,
        uint256 _totalPack,
        uint256 _totalSold,
        bool _whitelistStatus,
        bool _saleStatus,
        bool _limitPackStatus
    ) public onlyOwner {
        PackFactory = CAT_StarterPack(_PackFactory);
        whitelistStatus = _whitelistStatus;
        saleStatus = _saleStatus;
        BUSD = IERC20(_BUSD);
        pricePack = _pricePack;
        feeAddress = _feeAddress;
        timeEnd = _timeEnd;
        timeStart = _timeStart;
        totalPack = _totalPack;
        totalSold = _totalSold;
        limitPackStatus = _limitPackStatus;
    }

    function setWhitelist(address[] calldata listUser) public onlyOwner {
        for (uint256 index = 0; index < listUser.length; index++) {
            whiteList[listUser[index]] = true;
        }
    }

    function removeWhitelist(address[] calldata listUser) public onlyOwner {
        for (uint256 index = 0; index < listUser.length; index++) {
            whiteList[listUser[index]] = false;
        }
    }

    function checkWhitelist(address user) public view returns (bool) {
        return whiteList[user];
    }

    function getStartTime() public view returns (uint256) {
        return timeStart;
    }

    function getEndTime() public view returns (uint256) {
        return timeEnd;
    }

    function canBuy(uint256 _CurrentTime) public view returns (bool) {
        uint256 packAvaiableForLastDay = (((_CurrentTime - timeStart) /
            secondsFor6hours) + 1) * packIn6hours;
        if (totalSold < packAvaiableForLastDay) return true;

        return false;
    }

    function buyStarterPack() public nonReentrant {
        if (whitelistStatus == true) {
            require(
                checkWhitelist(msg.sender) == true,
                "Error : Invalid Whitelist"
            );
        }
        if (limitPackStatus == true) {
            require(
                canBuy(block.timestamp) == true,
                "Error: Invalid amount of package"
            );
        }

        require(saleStatus == true, "Error : Invalid Whitelist");
        require(
            BUSD.balanceOf(msg.sender) >= pricePack,
            "Error: Invalid balance of BUSD"
        );
        require(block.timestamp <= timeEnd, "Error: Invalid Time");
        require(block.timestamp >= timeStart, "Error: Invalid Time");
        require(totalSold < totalPack, "Error: Invalid Amount Package");

        BUSD.transferFrom(msg.sender, feeAddress, pricePack);
        PackFactory.mintStarterPack(msg.sender);

        if (whitelistStatus == true) {
            whiteList[msg.sender] = false;
        }
        totalSold++;
    }
}
