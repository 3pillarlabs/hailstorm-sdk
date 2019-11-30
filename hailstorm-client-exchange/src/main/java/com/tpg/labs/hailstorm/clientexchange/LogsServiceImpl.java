package com.tpg.labs.hailstorm.clientexchange;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class LogsServiceImpl implements LogsService, InitializingBean {

    private final List<LogEvent> cache = new ArrayList<>();
    private ObjectMapper objectMapper;

    @Autowired
    public void setObjectMapper(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        Resource eventsFile = new ClassPathResource("fake-events.json");
        cache.addAll(objectMapper.readValue(eventsFile.getFile(), new TypeReference<List<LogEvent>>() {})
                .stream().map(logEvent -> logEvent.decorate(Math.random())).collect(Collectors.toList()));
    }

    @Override
    public Flux<LogEvent> logStream() {
        return Flux.just(cache.toArray(new LogEvent[] {})).delayElements(Duration.ofSeconds(1));
    }
}
