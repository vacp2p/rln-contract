# Solidity API

## IVerifier

### verifyProof

```solidity
function verifyProof(uint256[2] a, uint256[2][2] b, uint256[2] c, uint256[2] input) external view returns (bool)
```

## RLN

### constructor

```solidity
constructor(uint256 membershipDeposit, uint256 depth, address _verifier) public
```

### \_validateRegistration

```solidity
function _validateRegistration(uint256 idCommitment) internal pure
```

_Inheriting contracts MUST override this function_

### \_validateSlash

```solidity
function _validateSlash(uint256 idCommitment, address payable receiver, uint256[8] proof) internal pure
```

## FullTree

```solidity
error FullTree()
```

The tree is full

## InsufficientDeposit

```solidity
error InsufficientDeposit(uint256 required, uint256 provided)
```

Invalid deposit amount

### Parameters

| Name     | Type    | Description                 |
| -------- | ------- | --------------------------- |
| required | uint256 | The required deposit amount |
| provided | uint256 | The provided deposit amount |

## DuplicateIdCommitment

```solidity
error DuplicateIdCommitment()
```

Member is already registered

## FailedValidation

```solidity
error FailedValidation()
```

Failed validation on registration/slashing

## InvalidIdCommitment

```solidity
error InvalidIdCommitment(uint256 idCommitment)
```

Invalid idCommitment

## InvalidReceiverAddress

```solidity
error InvalidReceiverAddress(address to)
```

Invalid receiver address, when the receiver is the contract itself or 0x0

## MemberNotRegistered

```solidity
error MemberNotRegistered(uint256 idCommitment)
```

Member is not registered

## MemberHasNoStake

```solidity
error MemberHasNoStake(uint256 idCommitment)
```

Member has no stake

## InsufficientWithdrawalBalance

```solidity
error InsufficientWithdrawalBalance()
```

User has insufficient balance to withdraw

## InsufficientContractBalance

```solidity
error InsufficientContractBalance()
```

Contract has insufficient balance to return

## InvalidProof

```solidity
error InvalidProof()
```

Invalid proof

## RlnBase

### Q

```solidity
uint256 Q
```

The Field

### MEMBERSHIP_DEPOSIT

```solidity
uint256 MEMBERSHIP_DEPOSIT
```

The deposit amount required to register as a member

### DEPTH

```solidity
uint256 DEPTH
```

The depth of the merkle tree

### SET_SIZE

```solidity
uint256 SET_SIZE
```

The size of the merkle tree, i.e 2^depth

### idCommitmentIndex

```solidity
uint256 idCommitmentIndex
```

The index of the next member to be registered

### stakedAmounts

```solidity
mapping(uint256 => uint256) stakedAmounts
```

The amount of eth staked by each member
maps from idCommitment to the amount staked

### members

```solidity
mapping(uint256 => uint256) members
```

The membership status of each member
maps from idCommitment to their index in the set

### memberExists

```solidity
mapping(uint256 => bool) memberExists
```

The membership status of each member

### withdrawalBalance

```solidity
mapping(address => uint256) withdrawalBalance
```

The balance of each user that can be withdrawn

### verifier

```solidity
contract IVerifier verifier
```

The groth16 verifier contract

### deployedBlockNumber

```solidity
uint32 deployedBlockNumber
```

the deployed block number

### imtData

```solidity
struct BinaryIMTData imtData
```

the Incremental Merkle Tree

### MemberRegistered

```solidity
event MemberRegistered(uint256 idCommitment, uint256 index)
```

Emitted when a new member is added to the set

#### Parameters

| Name         | Type    | Description                        |
| ------------ | ------- | ---------------------------------- |
| idCommitment | uint256 | The idCommitment of the member     |
| index        | uint256 | The index of the member in the set |

### MemberWithdrawn

```solidity
event MemberWithdrawn(uint256 idCommitment, uint256 index)
```

Emitted when a member is removed from the set

#### Parameters

| Name         | Type    | Description                        |
| ------------ | ------- | ---------------------------------- |
| idCommitment | uint256 | The idCommitment of the member     |
| index        | uint256 | The index of the member in the set |

### onlyValidIdCommitment

```solidity
modifier onlyValidIdCommitment(uint256 idCommitment)
```

### constructor

```solidity
constructor(uint256 membershipDeposit, uint256 depth, address _verifier) internal
```

### register

```solidity
function register(uint256 idCommitment) external payable virtual
```

Allows a user to register as a member

#### Parameters

| Name         | Type    | Description                    |
| ------------ | ------- | ------------------------------ |
| idCommitment | uint256 | The idCommitment of the member |

### \_register

```solidity
function _register(uint256 idCommitment, uint256 stake) internal virtual
```

Registers a member

#### Parameters

| Name         | Type    | Description                            |
| ------------ | ------- | -------------------------------------- |
| idCommitment | uint256 | The idCommitment of the member         |
| stake        | uint256 | The amount of eth staked by the member |

### \_validateRegistration

```solidity
function _validateRegistration(uint256 idCommitment) internal view virtual
```

_Inheriting contracts MUST override this function_

### slash

```solidity
function slash(uint256 idCommitment, address payable receiver, uint256[8] proof) external virtual
```

_Allows a user to slash a member_

#### Parameters

| Name         | Type            | Description                    |
| ------------ | --------------- | ------------------------------ |
| idCommitment | uint256         | The idCommitment of the member |
| receiver     | address payable |                                |
| proof        | uint256[8]      |                                |

### \_slash

```solidity
function _slash(uint256 idCommitment, address payable receiver, uint256[8] proof) internal virtual
```

_Slashes a member by removing them from the set, and adding their
stake to the receiver's available withdrawal balance_

#### Parameters

| Name         | Type            | Description                      |
| ------------ | --------------- | -------------------------------- |
| idCommitment | uint256         | The idCommitment of the member   |
| receiver     | address payable | The address to receive the funds |
| proof        | uint256[8]      |                                  |

### \_validateSlash

```solidity
function _validateSlash(uint256 idCommitment, address payable receiver, uint256[8] proof) internal view virtual
```

### withdraw

```solidity
function withdraw() external virtual
```

Allows a user to withdraw funds allocated to them upon slashing a member

### isValidCommitment

```solidity
function isValidCommitment(uint256 idCommitment) public pure returns (bool)
```

### \_verifyProof

```solidity
function _verifyProof(uint256 idCommitment, address receiver, uint256[8] proof) internal view virtual returns (bool)
```

_Groth16 proof verification_

### root

```solidity
function root() external view returns (uint256)
```

## Pairing

### G1Point

```solidity
struct G1Point {
  uint256 X;
  uint256 Y;
}
```

### G2Point

```solidity
struct G2Point {
  uint256[2] X;
  uint256[2] Y;
}
```

### P1

```solidity
function P1() internal pure returns (struct Pairing.G1Point)
```

#### Return Values

| Name | Type                   | Description         |
| ---- | ---------------------- | ------------------- |
| [0]  | struct Pairing.G1Point | the generator of G1 |

### P2

```solidity
function P2() internal pure returns (struct Pairing.G2Point)
```

#### Return Values

| Name | Type                   | Description         |
| ---- | ---------------------- | ------------------- |
| [0]  | struct Pairing.G2Point | the generator of G2 |

### negate

```solidity
function negate(struct Pairing.G1Point p) internal pure returns (struct Pairing.G1Point r)
```

#### Return Values

| Name | Type                   | Description                                                    |
| ---- | ---------------------- | -------------------------------------------------------------- |
| r    | struct Pairing.G1Point | the negation of p, i.e. p.addition(p.negate()) should be zero. |

### addition

```solidity
function addition(struct Pairing.G1Point p1, struct Pairing.G1Point p2) internal view returns (struct Pairing.G1Point r)
```

#### Return Values

| Name | Type                   | Description                 |
| ---- | ---------------------- | --------------------------- |
| r    | struct Pairing.G1Point | the sum of two points of G1 |

### scalar_mul

```solidity
function scalar_mul(struct Pairing.G1Point p, uint256 s) internal view returns (struct Pairing.G1Point r)
```

#### Return Values

| Name | Type                   | Description                                                                                                                 |
| ---- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| r    | struct Pairing.G1Point | the product of a point on G1 and a scalar, i.e. p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p. |

### pairing

```solidity
function pairing(struct Pairing.G1Point[] p1, struct Pairing.G2Point[] p2) internal view returns (bool)
```

#### Return Values

| Name | Type | Description                                                                                                                                                          |
| ---- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [0]  | bool | the result of computing the pairing check e(p1[0], p2[0]) _ .... _ e(p1[n], p2[n]) == 1 For example pairing([P1(), P1().negate()], [P2(), P2()]) should return true. |

### pairingProd2

```solidity
function pairingProd2(struct Pairing.G1Point a1, struct Pairing.G2Point a2, struct Pairing.G1Point b1, struct Pairing.G2Point b2) internal view returns (bool)
```

Convenience method for a pairing check for two pairs.

### pairingProd3

```solidity
function pairingProd3(struct Pairing.G1Point a1, struct Pairing.G2Point a2, struct Pairing.G1Point b1, struct Pairing.G2Point b2, struct Pairing.G1Point c1, struct Pairing.G2Point c2) internal view returns (bool)
```

Convenience method for a pairing check for three pairs.

### pairingProd4

```solidity
function pairingProd4(struct Pairing.G1Point a1, struct Pairing.G2Point a2, struct Pairing.G1Point b1, struct Pairing.G2Point b2, struct Pairing.G1Point c1, struct Pairing.G2Point c2, struct Pairing.G1Point d1, struct Pairing.G2Point d2) internal view returns (bool)
```

Convenience method for a pairing check for four pairs.

## Verifier

### VerifyingKey

```solidity
struct VerifyingKey {
  struct Pairing.G1Point alfa1;
  struct Pairing.G2Point beta2;
  struct Pairing.G2Point gamma2;
  struct Pairing.G2Point delta2;
  struct Pairing.G1Point[] IC;
}
```

### Proof

```solidity
struct Proof {
  struct Pairing.G1Point A;
  struct Pairing.G2Point B;
  struct Pairing.G1Point C;
}
```

### verifyingKey

```solidity
function verifyingKey() internal pure returns (struct Verifier.VerifyingKey vk)
```

### verify

```solidity
function verify(uint256[] input, struct Verifier.Proof proof) internal view returns (uint256)
```

### verifyProof

```solidity
function verifyProof(uint256[2] a, uint256[2][2] b, uint256[2] c, uint256[2] input) public view returns (bool r)
```

#### Return Values

| Name | Type | Description                 |
| ---- | ---- | --------------------------- |
| r    | bool | bool true if proof is valid |
