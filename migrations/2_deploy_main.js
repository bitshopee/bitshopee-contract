var main=artifacts.require("./BitShopeePayTask");


module.exports = async function(_deployer,_network) {
  if(_network=="bsctestnet"){
    await _deployer.deploy(main,"0x0A8548Bf245c01eCDD95a2052B5f176888f14FaA",5,"0x0A8548Bf245c01eCDD95a2052B5f176888f14FaA");
    // const flowCallInstance=await flowCall.deployed();
    // await _deployer.deploy(tokenReceiver);
    // const tokenReceiverInstance=await tokenReceiver.deployed();
    // await flowCallInstance.setTokenReceiver(tokenReceiverInstance.address);
    // await tokenReceiverInstance.setFlowCallAddress(flowCallInstance.address);
  }
  
};
