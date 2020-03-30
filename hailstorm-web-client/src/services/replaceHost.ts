import environment from "../environment";

export function replaceHost(uri: string): string {
  const url = new URL(uri);
  const fsURL = new URL(environment.fileServerBaseURL);
  url.hostname = fsURL.hostname;
  url.port = fsURL.port;
  return url.toString();
}
