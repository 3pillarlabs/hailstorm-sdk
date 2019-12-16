type Config = {
  fileServerBaseURL: string;
  apiBaseURL: string;
}

const common: Config = {
  fileServerBaseURL: "http://localhost:8080",
  apiBaseURL: "http://localhost:4567"
};

const dev: Config = {
  ...common,
};

const prod: Config = {
  ...common,
  fileServerBaseURL: "http://localhost:9000"
};

const config: Config = process.env.NODE_ENV === 'production' ? prod : dev;

export default {...config};
