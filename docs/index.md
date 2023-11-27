# Solidity API

## NotImplemented

```solidity
error NotImplemented()
```

## WakuRln

### contractIndex

```solidity
uint16 contractIndex
```

### tree

```solidity
struct LazyIMTData tree
```

### constructor

```solidity
constructor(address _poseidonHasher, uint16 _contractIndex) public
```

### \_register

```solidity
function _register(uint256 idCommitment) internal
```

Registers a member

#### Parameters

| Name         | Type    | Description                    |
| ------------ | ------- | ------------------------------ |
| idCommitment | uint256 | The idCommitment of the member |

### register

```solidity
function register(uint256[] idCommitments) external
```

### register

```solidity
function register(uint256 idCommitment) external payable
```

Allows a user to register as a member

#### Parameters

| Name         | Type    | Description                    |
| ------------ | ------- | ------------------------------ |
| idCommitment | uint256 | The idCommitment of the member |

### slash

```solidity
function slash(uint256 idCommitment, address payable receiver, uint256[8] proof) external pure
```

_Allows a user to slash a member_

#### Parameters

| Name         | Type            | Description                    |
| ------------ | --------------- | ------------------------------ |
| idCommitment | uint256         | The idCommitment of the member |
| receiver     | address payable |                                |
| proof        | uint256[8]      |                                |

### \_validateRegistration

```solidity
function _validateRegistration(uint256 idCommitment) internal view
```

_Inheriting contracts MUST override this function_

### \_validateSlash

```solidity
function _validateSlash(uint256 idCommitment, address payable receiver, uint256[8] proof) internal pure
```

### withdraw

```solidity
function withdraw() external pure
```

Allows a user to withdraw funds allocated to them upon slashing a member

### merkleRoot

```solidity
function merkleRoot() public view returns (uint256)
```

### numOfLeaves

```solidity
function numOfLeaves() public view returns (uint40)
```

### getElement

```solidity
function getElement(uint256 elementIndex) public view returns (uint256)
```

## StorageAlreadyExists

```solidity
error StorageAlreadyExists(address storageAddress)
```

## NoStorageContractAvailable

```solidity
error NoStorageContractAvailable()
```

## IncompatibleStorage

```solidity
error IncompatibleStorage()
```

## IncompatibleStorageIndex

```solidity
error IncompatibleStorageIndex()
```

## WakuRlnRegistry

### nextStorageIndex

```solidity
uint16 nextStorageIndex
```

### storages

```solidity
mapping(uint16 => address) storages
```

### usingStorageIndex

```solidity
uint16 usingStorageIndex
```

### poseidonHasher

```solidity
contract IPoseidonHasher poseidonHasher
```

### NewStorageContract

```solidity
event NewStorageContract(uint16 index, address storageAddress)
```

### onlyUsableStorage

```solidity
modifier onlyUsableStorage()
```

### initialize

```solidity
function initialize(address _poseidonHasher) external
```

### \_authorizeUpgrade

```solidity
function _authorizeUpgrade(address newImplementation) internal
```

\_Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
{upgradeTo} and {upgradeToAndCall}.

Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.

````solidity
function _authorizeUpgrade(address) internal override onlyOwner {}
```_

### _insertIntoStorageMap

```solidity
function _insertIntoStorageMap(address storageAddress) internal
````

### registerStorage

```solidity
function registerStorage(address storageAddress) external
```

### newStorage

```solidity
function newStorage() external
```

### register

```solidity
function register(uint256[] commitments) external
```

### register

```solidity
function register(uint16 storageIndex, uint256[] commitments) external
```

### register

```solidity
function register(uint16 storageIndex, uint256 commitment) external
```

### forceProgress

```solidity
function forceProgress() external
```

## LazyIMTData

```solidity
struct LazyIMTData {
  uint32 maxIndex;
  uint40 numberOfLeaves;
  mapping(uint256 => uint256) elements;
}
```

## LazyIMT

### SNARK_SCALAR_FIELD

```solidity
uint256 SNARK_SCALAR_FIELD
```

### MAX_DEPTH

```solidity
uint8 MAX_DEPTH
```

### MAX_INDEX

```solidity
uint40 MAX_INDEX
```

### init

```solidity
function init(struct LazyIMTData self, uint8 depth) public
```

### reset

```solidity
function reset(struct LazyIMTData self) public
```

### indexForElement

```solidity
function indexForElement(uint8 level, uint40 index) public pure returns (uint40)
```

### insert

```solidity
function insert(struct LazyIMTData self, uint256 leaf) public
```

### update

```solidity
function update(struct LazyIMTData self, uint256 leaf, uint40 index) public
```

### root

```solidity
function root(struct LazyIMTData self) public view returns (uint256)
```

### Z_0

```solidity
uint256 Z_0
```

### Z_1

```solidity
uint256 Z_1
```

### Z_2

```solidity
uint256 Z_2
```

### Z_3

```solidity
uint256 Z_3
```

### Z_4

```solidity
uint256 Z_4
```

### Z_5

```solidity
uint256 Z_5
```

### Z_6

```solidity
uint256 Z_6
```

### Z_7

```solidity
uint256 Z_7
```

### Z_8

```solidity
uint256 Z_8
```

### Z_9

```solidity
uint256 Z_9
```

### Z_10

```solidity
uint256 Z_10
```

### Z_11

```solidity
uint256 Z_11
```

### Z_12

```solidity
uint256 Z_12
```

### Z_13

```solidity
uint256 Z_13
```

### Z_14

```solidity
uint256 Z_14
```

### Z_15

```solidity
uint256 Z_15
```

### Z_16

```solidity
uint256 Z_16
```

### Z_17

```solidity
uint256 Z_17
```

### Z_18

```solidity
uint256 Z_18
```

### Z_19

```solidity
uint256 Z_19
```

### Z_20

```solidity
uint256 Z_20
```

### Z_21

```solidity
uint256 Z_21
```

### Z_22

```solidity
uint256 Z_22
```

### Z_23

```solidity
uint256 Z_23
```

### Z_24

```solidity
uint256 Z_24
```

### Z_25

```solidity
uint256 Z_25
```

### Z_26

```solidity
uint256 Z_26
```

### Z_27

```solidity
uint256 Z_27
```

### Z_28

```solidity
uint256 Z_28
```

### Z_29

```solidity
uint256 Z_29
```

### Z_30

```solidity
uint256 Z_30
```

### Z_31

```solidity
uint256 Z_31
```

### Z_32

```solidity
uint256 Z_32
```

### defaultZero

```solidity
function defaultZero(uint8 index) public pure returns (uint256)
```
