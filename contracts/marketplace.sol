// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";
import "./nft.sol";
import "./ref.sol";

contract CAT_Marketplace is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    address owner;
    address NFT_Factory;
    address feeAddress;

    uint256 _maxFeeListing = 500;
    uint256 _feeListing = 150;

    uint256 _maxFeeMarket = 500;
    uint256 _feeMarket = 150;

    uint256 _maxFeeRef = 500;
    uint256 _feeRef = 10;

    using SafeERC20 for IERC20;
    IERC20 public BUSD;
    IERC20 public CAT;
    AethrRef public Ref;

    constructor() {
        owner = msg.sender;
    }
    
    function initialize(
        address _Factory,
        address _BUSD,
        address _CATToken,
        address _RefAddress
    ) public onlyOwner(msg.sender) {
        NFT_Factory = _Factory;

        BUSD = IERC20(_BUSD);
        CAT = IERC20(_CATToken);
        Ref = AethrRef(_RefAddress);

        feeAddress = address(this);

        BUSD.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
        CAT.approve(
            address(this),
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        );
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    event BuyNFT(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address newOwner,
        uint256 price,
        bool sold
    );

    event CancelSell(uint256 tokenId);

    modifier onlyOwner(address sender) {
        require(sender == owner, "Is not Owner");
        _;
    }

    /**
     * @dev Set NFT Factory
     */
    function updateFactory(address _Factory) public {
        require(msg.sender == owner, "Only Owner");
        NFT_Factory = _Factory;
    }

    /* Places an item for sale on the marketplace */
    function createSale(uint256 tokenId, uint256 priceItem)
        public
        nonReentrant
    {
        require(priceItem > 0, "Price must be at least 0");

        require(priceItem > _feeMarket, "Price must be equal to listing price");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[tokenId] = MarketItem(
            itemId,
            NFT_Factory,
            tokenId,
            msg.sender,
            address(0),
            priceItem,
            false
        );
        // take fee listing
        BUSD.transferFrom(
            msg.sender,
            feeAddress,
            calculateFee(priceItem, _feeListing)
        );

        CAT_NFT(NFT_Factory).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemId,
            NFT_Factory,
            tokenId,
            msg.sender,
            address(0),
            priceItem,
            false
        );
    }

    /* Buy a marketplace item */
    function buyNFT(uint256 tokenId) public nonReentrant {
        uint256 itemId = idToMarketItem[tokenId].itemId;
        uint256 price = idToMarketItem[tokenId].price;
        address seller = idToMarketItem[tokenId].seller;
        bool is_sold = idToMarketItem[tokenId].sold;

        require(is_sold == false, "Buy NFT : Unavailable");
        require(
            BUSD.balanceOf(msg.sender) >= price,
            "Please submit the asking price in order to complete the purchase"
        );
        // transfer money to seller
        BUSD.transferFrom(
            msg.sender,
            idToMarketItem[tokenId].seller,
            price - calculateFee(price, _feeMarket)
        );

        if (Ref.getRef(msg.sender) != address(0)) {
            // take fee market
            BUSD.transferFrom(
                msg.sender,
                feeAddress,
                calculateFee(price, _feeMarket)
            );
            // take fee ref
            BUSD.transferFrom(
                msg.sender,
                Ref.getRef(msg.sender),
                calculateFee(price, _feeRef)
            );
        } else {
            // take fee market
            BUSD.transferFrom(
                msg.sender,
                feeAddress,
                calculateFee(price, _feeMarket) + calculateFee(price, _feeRef)
            );
        }

        CAT_NFT(NFT_Factory).transferFrom(address(this), msg.sender, tokenId);

        idToMarketItem[tokenId].owner = msg.sender;
        idToMarketItem[tokenId].sold = true;

        emit BuyNFT(
            itemId,
            NFT_Factory,
            tokenId,
            seller,
            msg.sender,
            price,
            false
        );

        delete idToMarketItem[tokenId];
        _itemsSold.increment();
    }

    function cancelSell(uint256 tokenId) public nonReentrant {
        bool is_sold = idToMarketItem[tokenId].sold;
        address seller = idToMarketItem[tokenId].seller;

        require(
            msg.sender == seller || msg.sender == owner,
            "Buy NFT : Is not Seller"
        );
        require(is_sold == false, "Buy NFT : Unavailable");
        CAT_NFT(NFT_Factory).transferFrom(address(this), msg.sender, tokenId);
        delete idToMarketItem[tokenId];
        emit CancelSell(tokenId);
    }

    function setFeeListing(uint256 fee) public onlyOwner(msg.sender) {
        require(fee <= _maxFeeListing, "Error input, fee < 500");
        _feeListing = fee;
    }

    function setFeeMarket(uint256 fee) public onlyOwner(msg.sender) {
        require(fee <= _maxFeeMarket, "Error input, fee < 500");
        _feeMarket = fee;
    }

    function setFeeRef(uint256 fee) public onlyOwner(msg.sender) {
        require(fee <= _maxFeeRef, "Error input, fee < 500");
        _feeRef = fee;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner(msg.sender) {
        feeAddress = _feeAddress;
    }

    function withdrawFee(address to, uint256 amount)
        public
        onlyOwner(msg.sender)
    {
        BUSD.transferFrom(address(this), to, amount);
    }

    function calculateFee(uint256 amount, uint256 _feePercent)
        public
        pure
        returns (uint256)
    {
        return (amount / 10000) * _feePercent;
    }
}
