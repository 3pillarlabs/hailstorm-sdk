package com.tpg.labs.hailstormfs;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;

@SpringBootTest
class HailstormFileServerApplicationTests {

	@MockBean
	StorageService storageService;

	@Test
	void contextLoads() {
	}

}
