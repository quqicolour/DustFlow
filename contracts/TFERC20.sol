//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

import "../interfaces/ITFERC20.sol";

contract TFERC20 is ITFERC20{
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply;
    address private owner;
    mapping(address => uint) private _balanceOf;
    mapping(address => mapping(address => uint)) private _allowance;

    function setNameAndSymbol(string memory thisName,string memory thisSymbol)external {
        require(msg.sender==owner);
        _name=thisName;
        _symbol=thisSymbol;
    }

    function _mint(address to, uint value) internal returns(bool){
        _totalSupply += value ;
        _balanceOf[to] += value;
        emit Transfer(address(0), to, value);
        return true;
    }

    function _burn(address from, uint value) internal {
        _balanceOf[from] -= value;
        _totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        _allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        _balanceOf[from] = _balanceOf[from] - value;
        _balanceOf[to] = _balanceOf[to] + value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (_allowance[from][msg.sender] >= 0) {
            _allowance[from][msg.sender] = _allowance[from][msg.sender] - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function totalSupply()external view returns(uint256){
        return _totalSupply;
    }

    function name()external view returns(string memory){
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balanceOf[account];
    }
 
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowance[owner][spender];
    }


}