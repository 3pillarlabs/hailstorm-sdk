package com.tpg.labs.hailstorm.clientexchange;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.lettuce.core.pubsub.StatefulRedisPubSubConnection;
import io.lettuce.core.pubsub.api.reactive.RedisPubSubReactiveCommands;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class LogsServiceImpl implements LogsService, InitializingBean {

    private final List<LogEvent> cache = new ArrayList<>();
    private ObjectMapper objectMapper;
    private StatefulRedisPubSubConnection<String, String> connection;

    @Autowired
    public void setObjectMapper(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Autowired
    public void setConnection(StatefulRedisPubSubConnection<String, String> connection) {
        this.connection = connection;
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        Resource eventsFile = new ClassPathResource("fake-events.json");
        cache.addAll(objectMapper.readValue(eventsFile.getFile(), new TypeReference<List<LogEvent>>() {})
                .stream().map(logEvent -> logEvent.decorate(Math.random())).collect(Collectors.toList()));
    }

    @Override
    public Flux<LogEvent> logStream() {
        RedisPubSubReactiveCommands<String, String> reactiveCommands = connection.reactive();
        reactiveCommands.subscribe("hailstorm-logs").subscribe();
        return reactiveCommands.observeChannels().map(channelMessage -> {
            String message = channelMessage.getMessage();
            LogEvent logEvent = null;
            try {
                logEvent = objectMapper.readValue(message, LogEvent.class);
            } catch (JsonProcessingException e) {
                throw new RuntimeException(e);
            }

            return logEvent;
        });
    }
}
