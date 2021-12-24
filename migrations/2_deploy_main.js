var main=artifacts.require("./BitShopeePayTask");


module.exports = async function(_deployer,_network) {
  if(_network=="bsctestnet"){
    await _deployer.deploy(main,
      "0x0A8548Bf245c01eCDD95a2052B5f176888f14FaA",0,"0x0A8548Bf245c01eCDD95a2052B5f176888f14FaA");
    // const flowCallInstance=await flowCall.deployed();
    // await _deployer.deploy(tokenReceiver);
    // const tokenReceiverInstance=await tokenReceiver.deployed();
    // await flowCallInstance.setTokenReceiver(tokenReceiverInstance.address);
    // await tokenReceiverInstance.setFlowCallAddress(flowCallInstance.address);
  }
  else{//production
    await _deployer.deploy(main,
      "0xDd5386F52884dF2cE858eeC8e434d9968E4d3B51",//admin
      0,
      "0x93155cA0a0C17831A6809e278f1f90C2bf25CdF0"//fee
      );
  }
  
};
