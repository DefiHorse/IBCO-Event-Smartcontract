
async function main() {
    // We get the contract to deploy
    const DefiHorse = await ethers.getContractFactory('DefiHorseIBCO');
    console.log('Deploying DefiHorseIBCO...');
    const defiHorse = await DefiHorse.deploy(
      '0x5fdAb5BDbad5277B383B3482D085f4bFef68828C', // DFH
      '0xe9e7cea3dedca5984780bafc599bd69add087d56' // BUSD
    );
    await defiHorse.deployed();
    console.log('DefiHorseIBCO deployed to:', defiHorse.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });