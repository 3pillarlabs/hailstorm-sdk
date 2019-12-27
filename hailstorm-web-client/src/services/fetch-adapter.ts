// fetch adapters to adhere to DRY

export async function fetchOK(input: RequestInfo, init?: RequestInit): Promise<Response> {
  let response: Response;
  try {
    response = await fetch(input, init);
  } catch (error) {
    throw $e(error);
  }

  if (!response.ok) {
    throw new Error(response.statusText);
  }

  return response;
}

export async function fetchGuard<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (error) {
    throw $e(error);
  }
}

function $e(reason: any): Error {
  return reason instanceof Error ? reason : new Error(reason);
}
