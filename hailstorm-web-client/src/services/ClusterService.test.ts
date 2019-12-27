import { ClusterService } from "./ClusterService";
import { AmazonCluster } from "../domain";

describe('ClusterService', () => {
  it('should create a cluster', async () => {
    const attrs: AmazonCluster = {
      type: "AWS",
      accessKey: "A",
      secretKey: "s",
      instanceType: "t2.small",
      maxThreadsByInstance: 25,
      region: "us-east-1",
      title: ""
    };

    const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(new Blob([
      JSON.stringify({...attrs, id: 223, title: "AWS us-east-1", code: "aws-223", projectId: 1})
    ])));

    const service = new ClusterService();
    const createdCluster = await service.create(1, attrs);
    expect(spy).toBeCalled();
    expect(createdCluster.id).toBeDefined();
  });

  it('should list project clusters', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(new Blob([
      JSON.stringify([{
        id: 223,
        title: "AWS us-east-1",
        type: "AWS",
        code: "aws-223",
        projectId: 1,
        accessKey: "A",
        secretKey: "S",
        instanceType: "t2.small",
        maxThreadsByInstance: 25,
        region: "us-east-1"
      }])
    ])));

    const service = new ClusterService();
    const data = await service.list(1);
    expect(spy).toHaveBeenCalled();
    expect(data.length).toEqual(1);
  });

  it('should reject the list promise if project does not exist', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(null, { statusText: "Cluster not found", status: 404 }));
    const service = new ClusterService();
    try {
      await service.list(1);
      fail("control should not reach here");
    } catch (error) {
      expect(error).toBeInstanceOf(Error);
    }

    expect(spy).toHaveBeenCalled();
  });

  it('should delete a cluster', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(null, { status: 204 }));
    const service = new ClusterService();
    await service.destroy(1, 223);
    expect(spy).toHaveBeenCalled();
  });

  it('should reject the promise if cluster deletion fails', async () => {
    const spy = jest.spyOn(window, 'fetch').mockResolvedValue(new Response(null, { statusText: "Cluster not found", status: 404 }));
    const service = new ClusterService();
    try {
      await service.destroy(1, 23);
      fail("control should not reach here");
    } catch (error) {
      expect(error).toBeInstanceOf(Error);
    }

    expect(spy).toHaveBeenCalled();
  });
});
