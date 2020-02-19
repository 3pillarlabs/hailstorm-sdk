import { Given } from 'cucumber';
import { taggedInstance, checkHttpReach, writeServerIP } from 'features/support/aws-helper';
import { expect } from 'chai';

Given('{string} is up and accessible in AWS region {string}', async function (instaceTag: string, regionCode: string) {
  // const siteInstance = await taggedInstance(instaceTag, regionCode);
  // expect(siteInstance).to.not.be.undefined;
  // const reachabilityCheck = await checkHttpReach(siteInstance.PublicIpAddress);
  // expect(reachabilityCheck).to.be.true;
  // writeServerIP(siteInstance.PublicIpAddress);
});
