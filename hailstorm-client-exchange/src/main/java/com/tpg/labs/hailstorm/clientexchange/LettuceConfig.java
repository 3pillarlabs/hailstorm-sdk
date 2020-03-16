package com.tpg.labs.hailstorm.clientexchange;

import io.lettuce.core.RedisClient;
import io.lettuce.core.RedisURI;
import io.lettuce.core.pubsub.StatefulRedisPubSubConnection;
import io.lettuce.core.resource.ClientResources;
import io.lettuce.core.resource.DefaultClientResources;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class LettuceConfig {

    private static final int DEFAULT_REDIS_PORT = 6379;
    private static final String DEFAULT_REDIS_HOST = "localhost";
    private static final String REDIS_HOST_OPTION = "redisHost";
    private static final String REDIS_PORT_OPTION = "redisPort";

    private final Logger logger = LoggerFactory.getLogger(LettuceConfig.class);

    private ApplicationArguments args;

    @Autowired
    public void setArgs(ApplicationArguments args) {
        this.args = args;
    }

    @Bean(destroyMethod = "shutdown")
    ClientResources clientResources() {
        return DefaultClientResources.create();
    }

    @Bean(destroyMethod = "shutdown")
    RedisClient redisClient(ClientResources clientResources) {
        final String redisHost = args.containsOption(REDIS_HOST_OPTION) ?
                args.getOptionValues(REDIS_HOST_OPTION).get(0) :
                DEFAULT_REDIS_HOST;

        final int redisPort = args.containsOption(REDIS_PORT_OPTION) ?
                new Integer(args.getOptionValues(REDIS_PORT_OPTION).get(0)) :
                DEFAULT_REDIS_PORT;

        logger.info("Starting hailstorm-client-exchange on {}:{}", redisHost, redisPort);
        return RedisClient.create(clientResources, RedisURI.create(redisHost, redisPort));
    }

    @Bean(destroyMethod = "close")
    StatefulRedisPubSubConnection<String, String> connection(RedisClient redisClient) {
        return redisClient.connectPubSub();
    }
}
