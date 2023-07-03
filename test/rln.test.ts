import { expect } from "chai";
import { ethers, deployments } from "hardhat";

describe("RLN", () => {
  beforeEach(async () => {
    await deployments.fixture(["RLN"]);
  });
});
