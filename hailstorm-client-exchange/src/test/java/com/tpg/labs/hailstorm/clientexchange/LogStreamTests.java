package com.tpg.labs.hailstorm.clientexchange;

import io.rsocket.RSocket;
import io.rsocket.RSocketFactory;
import io.rsocket.frame.decoder.PayloadDecoder;
import io.rsocket.transport.netty.client.WebsocketClientTransport;
import io.rsocket.transport.netty.server.WebsocketRouteTransport;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.http.codec.json.Jackson2JsonDecoder;
import org.springframework.http.codec.json.Jackson2JsonEncoder;
import org.springframework.messaging.rsocket.RSocketRequester;
import org.springframework.messaging.rsocket.RSocketStrategies;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.util.MimeType;
import org.springframework.util.MimeTypeUtils;
import reactor.core.Disposable;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.net.URI;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.*;

@ExtendWith(SpringExtension.class)
public class LogStreamTests {

    @Test
    void shouldConnect() throws Exception {
        HailstormClientExchangeApplication.main(new String[] {});

        RSocketStrategies strategies = RSocketStrategies.builder()
                .encoders(encoders -> encoders.add(new Jackson2JsonEncoder()))
                .decoders(decoders -> decoders.add(new Jackson2JsonDecoder()))
                .build();

        RSocket rSocket = RSocketFactory.connect()
                .mimeType("message/x.rsocket.routing.v0", MimeTypeUtils.APPLICATION_JSON_VALUE)
                .transport(WebsocketClientTransport.create(URI.create("ws://localhost:8080/rsocket")))
                .start()
                .block();

        List<LogEvent> capturedEvents = RSocketRequester.wrap(rSocket,
                MimeTypeUtils.APPLICATION_JSON,
                MimeTypeUtils.parseMimeType("message/x.rsocket.routing.v0"),
                strategies
        ).route("logs")
                .retrieveFlux(LogEvent.class)
                .collectList()
                .toFuture()
                .get();

        assertThat(capturedEvents).hasSizeGreaterThan(0);
    }
}
