import { expect } from "chai";
import { Given } from "cucumber";
import { writeServerIP } from "features/support/aws-helper";
import { httpOK, socketOK } from "features/support/dc-helper";

Given("'Hailstorm Site' is up and accessible at {string}", async function(siteHostOrIp: string) {
  const ok = await httpOK(siteHostOrIp);
  expect(ok).to.be.true;
  writeServerIP(siteHostOrIp, 'dc');
});

Given("data center machines are accessible", function(dataTable: {
  hashes: () => {host: string}[]
}) {
  dataTable.hashes().forEach(async ({host}) => {
    const ok = await socketOK(host, 22);
    expect(ok).to.be.true;
  });
});
