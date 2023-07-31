# Solidity API

## NotImplemented

```solidity
error NotImplemented()
```

## WakuRln

### constructor

```solidity
constructor(address _poseidonHasher) public
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
