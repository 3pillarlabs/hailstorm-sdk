package com.tpg.labs.hailstorm.clientexchange;

import io.lettuce.core.RedisClient;
import io.lettuce.core.pubsub.StatefulRedisPubSubConnection;
import static org.mockito.Mockito.*;

public class HailstormClientExchangeApplicationTestsConfig extends LettuceConfig {
    @Override
    StatefulRedisPubSubConnection<String, String> connection(RedisClient redisClient) {
        return mock(StatefulRedisPubSubConnection.class);
    }
}
