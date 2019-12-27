import { AmazonCluster, DataCenterCluster, Cluster } from "../domain";
import environment from "../environment";
import { fetchOK, fetchGuard } from './fetch-adapter';

export class ClusterService {

  async create(projectId: number, attrs: AmazonCluster | DataCenterCluster): Promise<Cluster> {
    console.log(`api ---- ClusterService#create(${projectId}, ${attrs})`);
    return fetchGuard<Cluster>(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/clusters`, {
        body: JSON.stringify(attrs),
        headers: {
          'Content-Type': 'application/json'
        },
        method: 'POST'
      });

      const data = await response.json();
      return data;
    });
  }

  async list(projectId: number): Promise<Cluster[]> {
    console.log(`api ---- ClusterService#list(${projectId})`);
    return fetchGuard<Cluster[]>(async () => {
      const response = await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/clusters`);
      const data: Cluster[] = await response.json();
      return data;
    });
  }

  async destroy(projectId: number, id: number): Promise<void> {
    console.log(`api ---- ClusterService#destroy(${projectId}, ${id})`);
    return fetchGuard<void>(async () => {
      await fetchOK(`${environment.apiBaseURL}/projects/${projectId}/clusters/${id}`, {
        method: 'DELETE'
      })
    });
  }
}
