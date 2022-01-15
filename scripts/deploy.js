// scripts/deploy.js
async function main() {
    // We get the contract to deploy
    const DefiHorse = await ethers.getContractFactory('DefiHorse');
    console.log('Deploying DefiHorse...');
    const defiHorse = await DefiHorse.deploy();
    await defiHorse.deployed();
    console.log('DefiHorse deployed to:', defiHorse.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });