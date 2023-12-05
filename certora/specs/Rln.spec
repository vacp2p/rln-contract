methods {
  function root() external returns (uint256) envfree;
}

rule checkDefaultRootIsCorrect {
  uint256 defaultRoot = 15019797232609675441998260052101280400536945603062888308240081994073687793470;

  assert root() == input;
}
