// SPDX-License-Identifier: Moinho

pragma solidity ^0.8.0;


interface IWETH {    
    function deposit() external payable;
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Ownable {
    address private _owner;

    modifier onlyOwner {
        require(msg.sender == _owner);
        _;
    }

    constructor () {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

}

contract Licenseable is Ownable {

    event Discount(address to, uint16 percent);
    event Pricebot(uint256 price);
    event Licensed(address to);

    mapping(address => uint256) internal _expireLicense;
    mapping(address => uint256) internal _getDiscount;

    uint256 private _priceLicense;
    
    constructor () {
        _expireLicense[msg.sender] = block.timestamp + 1000 days;
    }

    function addLicense(address addr_, uint256 expireLicense_) public onlyOwner {
        _expireLicense[addr_] = expireLicense_;
    }
   
    function delLicense(address addr_) public onlyOwner {
        _expireLicense[addr_] = block.timestamp;
    }

    function setPriceLicense(uint256 price_) public onlyOwner {
        _priceLicense = price_;
        emit Pricebot(price_);
    }

    function addDiscount(address addr_, uint16 discount_) public onlyOwner {        
        _getDiscount[addr_] = discount_;
        emit Discount(addr_, discount_);
    }

    function getLicense() public payable {
        require(_expireLicense[msg.sender] < block.timestamp);

        if(_getDiscount[msg.sender] > 0){
            uint256 discount = _priceLicense - (_priceLicense * _getDiscount[msg.sender] / 100);
            require(msg.value == discount);

            _getDiscount[msg.sender] = 0;
        } else {
            require(msg.value == _priceLicense);
        }        

        _expireLicense[msg.sender] = block.timestamp + 365 days;
        emit Licensed(msg.sender);
    }

    function statusLicense(address addr_) public view returns(uint256) {
        return _expireLicense[addr_];
    }

    function statusDiscount(address addr_) public view returns(uint256) {
        return _getDiscount[addr_];
    }

    function priceLicense() public view returns (uint256) {

        if(_getDiscount[msg.sender] > 0){
            return _priceLicense - (_priceLicense * _getDiscount[msg.sender] / 100);
        } else {
            return _priceLicense;
        }
        
    }

}

contract Economy is Licenseable {
    //TESTNET 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd
    //MAINNET 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
    address    internal _WETH   =  0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;

    event Received(address from, uint256 value);
    event Withdrawal(address to,uint256 value);

    mapping(address => uint256) internal _balances;    

    receive () external payable {
        _balances[msg.sender] = msg.value;
        IWETH(_WETH).deposit{value: msg.value}();
        emit Received(msg.sender, msg.value);
    }

    function Withdraw() public {

        uint256 fromBalance = _balances[msg.sender];

        require(fromBalance >= 0, "ERC20: transfer amount exceeds balance");
        
        _balances[msg.sender] = 0;
        IERC20(_WETH).transfer(msg.sender,fromBalance);        

        emit Withdrawal(msg.sender,fromBalance);
    }

    function balanceOf(address addr_) public view returns(uint256) {
        return _balances[addr_];
    }

}

contract ProxyBot is Economy {    
    address private _implementation;

    function upgrade (address impl_) public onlyOwner {
        _implementation = impl_;
    }

    fallback () external {
        address _impl = _implementation;        

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())

            let result := delegatecall(gas(),_impl,ptr,calldatasize(),0,0)
            let resultsize := returndatasize()
            returndatacopy(ptr,0,resultsize)

            switch result 
            case 0 {revert(ptr,resultsize)}
            default {return(ptr,resultsize)}
        }
    }    
}
