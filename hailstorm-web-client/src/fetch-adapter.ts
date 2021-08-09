// fetch adapters to adhere to DRY

export async function fetchOK(input: RequestInfo, init?: RequestInit): Promise<Response> {
  let response: Response;
  try {
    response = await fetch(input, init);
  } catch (error) {
    throw $e(error);
  }

  if (!response.ok) {
    const text = await response.text();
    throw new Error(JSON.stringify({statusText: response.statusText, status: response.status, text}));
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

export function extractGuardError(error: Error): Error {
  const jsonText = `[${error.message}]`;
  const jsonAry = JSON.parse(jsonText);
  if (typeof(jsonAry[0]) === 'object') {
    const errorResponse = jsonAry[0];
    if (Object.keys(errorResponse).includes('text')) {
      return JSON.parse(errorResponse.text);
    }
  }

  return error;
}

function $e(reason: any): Error {
  return reason instanceof Error ? reason : new Error(reason);
}
