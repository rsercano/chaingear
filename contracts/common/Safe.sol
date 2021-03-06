pragma solidity 0.4.24;


/**
* @title Safe contract
* @author cyber•Congress
* @dev Allows store etheirs and claim them by owner
* @notice not recommend to use before release!
*/
contract Safe {
    
    /*
    *  Storage
    */

    address public owner;

    /*
    *  Constructor
    */

    /**
    * @dev Constructor of contract, payable
    */
    constructor()
        public
        payable
    {
        owner = msg.sender;
    }

    /*
    *  Public Functions
    */

    /**
    * @dev Allows direct send only by owner.
    */
    function()
        public
        payable
    {
        require(msg.sender == owner);
    }

    /**
    * @dev Allows owner (chaingear) claim funds and transfer them to token-entry owner
    * @param _entryOwner address transfer to, token-entry owner
    * @param _amount uint claimed amount by token-entry owner
    */
    function claim(
        address _entryOwner,
        uint256 _amount
    )
        public
    {
        require(msg.sender == owner);
        _entryOwner.transfer(_amount);
    }

}
