// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract FreeBe is ERC20, ERC20Permit {
    constructor() ERC20("FreeBe", "FB") ERC20Permit("FreeBe") {}

    // uint128 private _denominatorShift = 1<<50;

    // uint128 private _numerator = 1<<64;

    mapping(uint256 => address account) private _commodityProducter;

    mapping(uint256 => uint256) private _commodityPrices;

    mapping(uint256 => uint256) private _commodityFreeBePrices;

    uint256 private _commondityId = 1;

    /**
     * 使用 FreeBe 积分购买，这本质是积分的再分配，不产生新的积分，但能提升每个人在 FreeBe 市场中可支配的份额
     * 更多的积分也意味着更多的价值，积分再分配也意味着获得的合约余额中的比例的增加
     */
    function buyCommondityWithFreeBe(uint256 _id) external  {
        address producter = _commodityProducter[_id];
        require(producter != address(0), "commondity not exist");
        address account = _msgSender();
        uint256 freebePrice = _commodityFreeBePrices[_commondityId];
        uint256 balance = balanceOf(account);
        require(balance >= freebePrice, "insufficient freebe amount");

        uint256 fee = _mulDiv(freebePrice, 10, 100);
        _transfer(account, producter, freebePrice);
        _transfer(account, address(this), fee);
    }

    /**
     * 购买商品，购买后，收益归产品的生产者，平台收取 10% 的收益，这部分收益会做为合约余额成为所有人的提现基础
     */
    function buyCommondity(uint256 _id) external payable  {
        address producter = _commodityProducter[_id];
        require(producter != address(0), "commondity not exist");
    
        uint256 price = _commodityPrices[_id];
        uint256 value = msg.value;
        require(value >= price, "insufficient pay value");
        address account = _msgSender();
        uint256 reback = value - price;
        uint256 fee = _mulDiv(price, 10, 100);
        payable(producter).transfer(price - fee);
        payable(_msgSender()).transfer(reback);

        emit BuyCommodity(account, _id);
    }

    /**
     * 更新商品的价格
     */
    function updateCommondity(uint256 _id, uint256 _price, uint256 _freebePrice) external  {
        address producter = _commodityProducter[_id];
        require(producter != address(0), "commondity not exist");
        address account = _msgSender();
        require(producter == account, "you not the commondity owner");

        _commodityPrices[_commondityId] = _price;
        _commodityFreeBePrices[_commondityId] = _freebePrice;

        emit UpdateCommodity(account, _id, _price, _freebePrice);
    }

    /**
     * 创建商品，每个人/项目都能在 FreeBe 中创建商品，并获得收益
     * 对于项目，必须在 FreeBe 中创建对应的商品，做为项目最终输出给用户的价值载体
     */
    function createCommondity(uint256 _price, uint256 _freebePrice) external payable  {
        require(msg.value > 0, "amount must be greater than zero");

        uint256 value = msg.value;
        uint256 _freebe = _valueToFreeBe(value);
        require(_freebe >= 100000000000000000000, "amount value must be greater than 1000 freebe");
        address account = _msgSender();
        _commodityProducter[_commondityId] = account;
        _commodityPrices[_commondityId] = _price;
        _commodityFreeBePrices[_commondityId] = _freebePrice;
        _commondityId++;

        emit CreateCommodity(account, _commondityId, _price, _freebePrice);
    }

    /**
     * 通过 Dao 币购买 FreeBe 积分，购买比例存在一个默认值，并随着合约中的 Dao 币变化而变化
     */
    function mint() external payable {
        require(msg.value > 0, "Donation amount must be greater than zero");
        address account = _msgSender();
        uint256 value = msg.value;
        _update(address(0), account, _valueToFreeBe(value));
        
        emit DonationReceived(account, msg.value);
    }

    /**
     * 提现，根据提现积分和总积分的比例提取合约中的 Dao 币余额
     */
    function withdraw(uint256 _amount) external payable {
        address account = _msgSender();
        uint256 _balance = balanceOf(account);
        require(_amount <= _balance, "Insufficient freebe balance");
        uint256 _value = _freeBeToValue(_amount);
        uint256 _contranctBalance = address(this).balance;
        require(_value <= _contranctBalance, "Insufficient contract balance");

        _burn(account, _amount);

        payable(account).transfer(_value);
        emit FundsWithdrawn(account, _amount, _value);
    }

    /**
     * 获取合约余额
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * 获取余额
     */
    function getBalance() external view returns (uint256) {
        address account = _msgSender();
        return account.balance;
    }

    /**
     * 将转入的价值转为积分
     */
    function _valueToFreeBe(uint256 value) internal virtual returns (uint256)  {
        uint256 supply = totalSupply();
        if(supply == 0) {
            return value * 10000;
        }
        return _mulDiv(value, supply, address(this).balance - value);
    }

    /**
     * 计算 FreeBe 积分的价值
     */
    function _freeBeToValue(uint256 value) internal virtual returns (uint256)  {
        return _mulDiv(value, address(this).balance, totalSupply());
    }

    /**
     * 执行比例计算
     */
    function _mulDiv (uint256 x, uint256 y, uint256 z) internal virtual pure returns (uint256){
        uint256 a = x / z; 
        uint256 b = x % z; // x = a * z + b
        uint256 c = y / z; 
        uint256 d = y % z; // y = c * z + d
        return a * c * z + a * d + b * c + b * d / z;
    }


    event DonationReceived(address indexed donor, uint256 amount);

    event FundsWithdrawn(address indexed owner, uint256 famount, uint256 amount);

    event CreateCommodity(address indexed producter, uint256 id, uint256 price, uint256 freebePrice);

    event UpdateCommodity(address indexed producter, uint256 id, uint256 price, uint256 freebePrice);

    event BuyCommodity(address indexed buyer, uint256 id);
}