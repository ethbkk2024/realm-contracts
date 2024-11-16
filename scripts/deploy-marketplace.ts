import {ethers} from 'hardhat';

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // We get the contract to deploy

    const [deployer]: any = await ethers.getSigners();
    console.log(`account: ${deployer.address}`);
    const Marketplace = await ethers.getContractFactory('Marketplace');
    const _marketplace: any = await Marketplace.deploy(
      '0x1c5f75d830F263A0351E7DFCCb434b0C782eDB0E', // nft address
      '0x858dA671e3b109da7f3f8A74348c997F5eEBbCa3', // erc20 address
      deployer.address, // game server
      deployer.address
    );

    console.log('marketplace deployed to:', _marketplace.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
