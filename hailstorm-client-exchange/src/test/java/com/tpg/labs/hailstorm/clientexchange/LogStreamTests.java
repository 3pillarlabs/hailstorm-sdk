package com.tpg.labs.hailstorm.clientexchange;

import io.lettuce.core.RedisClient;
import io.lettuce.core.RedisURI;
import io.lettuce.core.api.sync.RedisCommands;
import io.lettuce.core.resource.ClientResources;
import io.lettuce.core.resource.DefaultClientResources;
import io.rsocket.RSocket;
import io.rsocket.RSocketFactory;
import io.rsocket.transport.netty.client.WebsocketClientTransport;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.http.codec.json.Jackson2JsonDecoder;
import org.springframework.http.codec.json.Jackson2JsonEncoder;
import org.springframework.messaging.rsocket.RSocketRequester;
import org.springframework.messaging.rsocket.RSocketStrategies;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.util.MimeTypeUtils;

import java.net.URI;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

@ExtendWith(SpringExtension.class)
public class LogStreamTests {

    Logger logger = LoggerFactory.getLogger(this.getClass());

    @Test
    @Disabled("Needs working Redis connection")
    void shouldConnect() throws Exception {
        HailstormClientExchangeApplication.main(new String[] {});

        Thread.sleep(4000);

        ExecutorService taskExecutor = Executors.newSingleThreadExecutor();
        Future<List<LogEvent>> future = taskExecutor.submit(() -> {
            logger.info("Task started...");
            RSocketStrategies strategies = RSocketStrategies.builder()
                    .encoders(encoders -> encoders.add(new Jackson2JsonEncoder()))
                    .decoders(decoders -> decoders.add(new Jackson2JsonDecoder()))
                    .build();

            RSocket rSocket = RSocketFactory.connect()
                    .mimeType("message/x.rsocket.routing.v0", MimeTypeUtils.APPLICATION_JSON_VALUE)
                    .transport(WebsocketClientTransport.create(URI.create("ws://localhost:8080/rsocket")))
                    .start()
                    .block();

            assertThat(rSocket).isNotNull();
            List<LogEvent> capturedEvents = new ArrayList<>();
            RSocketRequester.wrap(rSocket,
                    MimeTypeUtils.APPLICATION_JSON,
                    MimeTypeUtils.parseMimeType("message/x.rsocket.routing.v0"),
                    strategies
            ).route("logs")
                    .retrieveFlux(LogEvent.class)
                    .doOnNext(capturedEvents::add)
                    .subscribe();

            logger.debug("{}", capturedEvents);
            return capturedEvents;
        });

        Thread.sleep(750);


        ClientResources clientResources = DefaultClientResources.create();
        RedisClient redisClient = RedisClient.create(clientResources, RedisURI.create("localhost", 6379));
        RedisCommands<String, String> command = redisClient.connect().sync();
        Resource eventsFile = new ClassPathResource("fake-events.log");
        final long numMessages = Files.lines(eventsFile.getFile().toPath()).map(s -> {
            command.publish("hailstorm-logs", s);
            return s.length();
        }).count();

        command.flushall();

        Thread.sleep(500);

        List<LogEvent> capturedEvents = future.get(5, TimeUnit.SECONDS);
        assertThat(capturedEvents.size()).isEqualTo(numMessages);
    }
}
