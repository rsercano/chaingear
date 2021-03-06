pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../common/SplitPaymentChangeable.sol";
import "../common/RegistryBasic.sol";
import "../common/Safe.sol";
import "./ChaingearCore.sol";

// TODO: move out
import "./RegistryCreator.sol";


/**
* @title Chaingear - the most expensive Regisrty
* @author cyber•Congress
* @dev Main metaregistry contract 
* @notice not recommend to use before release!
*/
contract Chaingear is ERC721Token, SplitPaymentChangeable, ChaingearCore {

    using SafeMath for uint256;

    /*
    *  Constructor
    */

	/**
	* @dev Chaingear constructor, pre-deployment of Chaingear
	* @param _benefitiaries address[] addresses of Chaingear benefitiaries
	* @param _shares uint256[] array with amount of shares
	* @param _description string description of Chaingear
	* @param _registrationFee uint Registration fee for registry creation
	* @param _chaingearName string Chaingear name
	* @param _chaingearSymbol string Chaingear symbol
	*/
    constructor(
        address[] _benefitiaries,
        uint256[] _shares,
        string _description,
        uint _registrationFee,
        string _chaingearName,
        string _chaingearSymbol
    )
        SplitPaymentChangeable(_benefitiaries, _shares)
        ERC721Token(_chaingearName, _chaingearSymbol)
        public
        payable
    {
        registryRegistrationFee = _registrationFee;
        chaingearDescription = _description;
    
        registrySafe = new Safe();
    }
    
    /*
    *  Public functions
    */

    /**
    * @dev Add and tokenize registry with specified parameters to Chaingear.
	* @dev Registration fee is required to send with tx.
	* @dev Tx sender become Creator of Registry, chaingear become Owner of Registry
    * @param _version version of registry code which added to chaingear
    * @param _benefitiaries address[] addresses of Chaingear benefitiaries
    * @param _shares uint256[] array with amount of shares
    * @param _name string, Registry name
    * @param _symbol string, Registry symbol
    * @return address new Registry contract address
    * @return uint256 new Registry ID in Chaingear contract, same token ID
    */
    function registerRegistry(
        string _version,
        address[] _benefitiaries,
        uint256[] _shares,
        string _name,
        string _symbol
    )
        public
        payable
        whenNotPaused
        returns (
            address,
            uint256
        )
    {
        require(registryAddresses[_version] != 0x0);
        require(registryRegistrationFee == msg.value);
        require(registryNamesIndex[_name] == false);
        require(registrySymbolsIndex[_symbol] == false);

        return createRegistry(
            _version,
            _benefitiaries,
            _shares,
            _name,
            _symbol
        );
    }

    /**
    * @dev Allows transfer adminship of Registry to new admin
    * @dev Transfer associated token and set admin of registry to new admin
    * @param _registryID uint256 Registry-token ID
    * @param _newOwner address Address of new admin
    */
    function updateRegistryOwnership(
        uint256 _registryID,
        address _newOwner
    )
        public
        whenNotPaused
        onlyOwnerOf(_registryID)
    {
        //TODO optimizing? delete inf
        RegistryBasic(registries[_registryID].contractAddress).transferAdminRights(_newOwner);
        /* registries[_registryID].admin = _newOwner; */

        removeTokenFrom(msg.sender, _registryID);
        addTokenTo(_newOwner, _registryID);

        emit RegistryTransferred(msg.sender, _registryID, _newOwner);
    }

    /**
    * @dev Allows to unregister created Registry from Chaingear
    * @dev Only possible when safe of Registry is empty
    * @dev Burns associated registry token and transfer Registry adminship to creator
    * @param _registryID uint256 Registry-token ID
    */
    function unregisterRegistry(uint256 _registryID)
        public
        whenNotPaused
        onlyOwnerOf(_registryID)
    {        
        address registryAddress = registries[_registryID].contractAddress;
        require(RegistryBasic(registryAddress).getSafeBalance() == 0);

        uint256 registryIndex = allTokensIndex[_registryID];
        uint256 lastRegistryIndex = registries.length.sub(1);
        RegistryMeta storage lastRegistry = registries[lastRegistryIndex];

        registries[registryIndex] = lastRegistry;
        delete registries[lastRegistryIndex];
        registries.length--;
        
        address currentAdmin = RegistryBasic(registryAddress).getAdmin();
        RegistryBasic(registryAddress).transferOwnership(currentAdmin);

        _burn(msg.sender, _registryID);

        string memory registryName = RegistryBasic(registryAddress).name();
        emit RegistryUnregistered(msg.sender, registryName);
    }
    
    function fundRegistry(uint256 _registryID)
        public
        whenNotPaused
        payable
    {
        uint256 weiAmount = msg.value;
        registries[_registryID].currentRegistryBalanceETH = registries[_registryID].currentRegistryBalanceETH.add(weiAmount);
        registries[_registryID].accumulatedRegistryETH = registries[_registryID].accumulatedRegistryETH.add(weiAmount);
        registrySafe.transfer(msg.value);

        emit RegistryFunded(_registryID, msg.sender);
    }

    function claimEntryFunds(
        uint256 _registryID,
        uint256 _amount
    )
        public
        whenNotPaused
        onlyOwnerOf(_registryID)
    {
        require(_amount <= registries[_registryID].currentRegistryBalanceETH);
        registries[_registryID].currentRegistryBalanceETH = registries[_registryID].currentRegistryBalanceETH.sub(_amount);
        Safe(registrySafe).claim(msg.sender, _amount);

        emit RegistryFundsClaimed(_registryID, msg.sender, _amount);
    }

    /*
    *  Private functions
    */

    /**
    * @dev Private function for registry creation
    * @dev Pass Registry params and bytecode to RegistryCreator to current builder
    * @param _version version of registry code which added to chaingear
    * @param _benefitiaries address[] addresses of Chaingear benefitiaries
    * @param _shares uint256[] array with amount of shares
    * @param _name string, Registry name
    * @param _symbol string, Registry symbol
    * @return address new Registry contract address
    * @return uint256 new Registry ID in Chaingear contract, same token ID
    */
    function createRegistry(
        string _version,
        address[] _benefitiaries,
        uint256[] _shares,
        string _name,
        string _symbol
    )
        private
        returns (
            address,
            uint256
        )
    {
        address registryContract = RegistryCreator(registryAddresses[_version]).create(
            _benefitiaries,
            _shares,
            _name,
            _symbol
        );
        
        RegistryBasic(registryContract).transferAdminRights(msg.sender);
        
        RegistryMeta memory registry = (RegistryMeta(
        {
            /* name: _name,
            symbol: _symbol, */
            contractAddress: registryContract,
            creator: msg.sender,
            version: _version,
            linkABI: registryABIsLinks[_version],
            registrationTimestamp: block.timestamp,
            /* admin: msg.sender, */
            currentRegistryBalanceETH: 0,
            accumulatedRegistryETH: 0
        }));

        uint256 registryID = registries.push(registry) - 1;
        _mint(msg.sender, registryID);
        
        registryNamesIndex[_name] = true;
        registrySymbolsIndex[_symbol] = true;
        
        emit RegistryRegistered(_name, registryContract, msg.sender, registryID);

        return (
            registryContract,
            registryID
        );
    }
    
}
