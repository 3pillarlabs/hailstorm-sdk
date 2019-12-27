import { fetchOK } from "./fetch-adapter";

describe('fetch-adapter', () => {
  describe('fetchOK()', () => {
    it('should return the fetch response if its ok', async () => {
      const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(new Blob([
        JSON.stringify([])
      ]), { status: 200 }));

      const response = await fetchOK('http://any.location');
      expect(response.ok).toBeTruthy();
      expect(spy).toBeCalled();
    });

    it('should reject the promise if fetch response is not ok', async () => {
      const spy = jest.spyOn(window, 'fetch').mockResolvedValueOnce(new Response(null, { status: 404 }));
      try {
        await fetchOK('http://any.location');
        fail("Control should not reach here");
      } catch (error) {
        expect(error).toBeInstanceOf(Error);
      }

      expect(spy).toHaveBeenCalled();
    });

    it('should reject the promise if fetch is rejected', (done) => {
      const spy = jest.spyOn(window, 'fetch').mockRejectedValue("Unknown error");
      fetchOK('http://any.location')
        .catch((error) => {
          done();
          expect(error).toBeInstanceOf(Error);
          expect(spy).toBeCalled();
        })
    });
  });

});
