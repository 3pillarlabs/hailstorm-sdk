import { Then } from "cucumber";
import { expect } from 'chai';
import config from 'environment.e2e';
import axios from 'axios';

Then("{int} load agent(s) should exist", async function(loadAgentCount) {
  const response = await axios.get(`${config.apiBaseURL}/projects/${this.projectId}/load_agents`);
  expect(response.status).to.equal(200);
  expect(response.data.length).to.equal(loadAgentCount);
});
