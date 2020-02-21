package com.tpg.labs.hailstorm.clientexchange;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.lettuce.core.pubsub.StatefulRedisPubSubConnection;
import io.lettuce.core.pubsub.api.reactive.ChannelMessage;
import io.lettuce.core.pubsub.api.reactive.RedisPubSubReactiveCommands;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.text.MessageFormat;
import java.util.ArrayList;
import java.util.List;

@Service
public class LogsServiceImpl implements LogsService, InitializingBean {

    private static final String DEFAULT_CHANNEL_PATTERN = "hailstorm-logs";

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private ObjectMapper objectMapper;
    private StatefulRedisPubSubConnection<String, String> connection;
    private String channelPattern = DEFAULT_CHANNEL_PATTERN;
    private Flux<String> eventSource;

    @Autowired
    public void setObjectMapper(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Autowired
    public void setConnection(StatefulRedisPubSubConnection<String, String> connection) {
        this.connection = connection;
    }

    public void setChannelPattern(String channelPattern) {
        this.channelPattern = channelPattern;
    }

    public void setEventSource(Flux<String> eventSource) {
        this.eventSource = eventSource;
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        RedisPubSubReactiveCommands<String, String> reactiveCommands = connection.reactive();
        reactiveCommands.subscribe(channelPattern).toFuture().get();
        eventSource = reactiveCommands.observeChannels().map(ChannelMessage::getMessage);
        logger.debug("Event source configured");
    }

    @Override
    public Flux<LogEvent> logStream() {
        logger.debug("logStream");
        return eventSource
                .map(message -> {
                    LogEvent logEvent = null;
                    try {
                        logEvent = objectMapper.readValue(message, LogEvent.class);
                    } catch (JsonProcessingException e) {
                        throw new RuntimeException(e);
                    }

                    return LogEvent.build(logEvent);
                })
                .onErrorContinue((throwable, o) -> {
                    logger.warn(throwable.getMessage());
                });
    }
}
