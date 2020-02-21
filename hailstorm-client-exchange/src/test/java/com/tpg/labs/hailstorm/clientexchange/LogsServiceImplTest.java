package com.tpg.labs.hailstorm.clientexchange;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import reactor.core.publisher.Flux;

import java.nio.file.Files;
import java.time.Duration;
import java.util.List;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;

class LogsServiceImplTest {

    @Test
    void logStream() throws Exception {
        Resource eventsFile = new ClassPathResource("fake-events.log");
        Stream<String> stream = Files.lines(eventsFile.getFile().toPath());
        Flux<String> flux = Flux.fromStream(stream);

        ObjectMapper mapper = new ObjectMapper();

        LogsService service = new LogsServiceImpl();
        ((LogsServiceImpl) service).setEventSource(flux);
        ((LogsServiceImpl) service).setObjectMapper(mapper);

        LogEvent event = service.logStream().take(1).blockFirst(Duration.ofMillis(100));
        assertThat(event).isNotNull();
        assertThat(event.getId()).isGreaterThan(0);
    }

    @Test
    void logStream_on_error_continue() throws Exception {
        Flux<String> flux = Flux.just(
            "[\"wrong format\"]",
            "{ \"priority\": 1, \"message\": \"Starting Tests...\", \"timestamp\": 1582264238655 }"
        );

        ObjectMapper mapper = new ObjectMapper();

        LogsService service = new LogsServiceImpl();
        ((LogsServiceImpl) service).setEventSource(flux);
        ((LogsServiceImpl) service).setObjectMapper(mapper);

        List<LogEvent> events = service.logStream().collectList().block(Duration.ofMillis(100));
        assertThat(events).hasSize(1);
    }
}
