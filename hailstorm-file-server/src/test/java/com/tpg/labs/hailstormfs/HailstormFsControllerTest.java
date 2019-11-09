package com.tpg.labs.hailstormfs;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.ResultHandler;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.io.FileNotFoundException;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.mockito.Mockito.*;

@SpringBootTest
@AutoConfigureMockMvc
class HailstormFsControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private StorageService storageService;

    @Test
    public void shouldRespondToOptions() throws Exception {
        this.mvc.perform(options("/upload"))
            .andExpect(status().is2xxSuccessful());
    }

    @Test
    public void shouldSaveUploadedFile() throws Exception {
        when(storageService.saveFile(any(FileMetaData.class), any(FileTransferActor.class)))
                .thenReturn("hdfs:///1234567/file.jmx");

        MockMultipartFile multipartFile = new MockMultipartFile(
                "file",
                "test.jtl",
                "text/xml",
                "<jtl></jtl>".getBytes()
        );

        this.mvc.perform(multipart("/upload").file(multipartFile))
                .andExpect(status().is2xxSuccessful());

        verify(storageService).saveFile(any(FileMetaData.class), any(FileTransferActor.class));
    }

    @Test
    public void shouldDeleteFile() throws Exception {
        final String fileId = "ceb007e9182";
        MockHttpServletRequestBuilder builder = delete("/" + fileId);
        this.mvc.perform(builder).andExpect(status().is2xxSuccessful());
        verify(storageService).deleteFile(fileId);
    }

    @Test
    public void shouldServeFile() throws Exception {
        final String content = "Hello world";
        when(storageService.getFile(anyString(), anyString()))
                .thenReturn(new ByteArrayResource(content.getBytes()));

        this.mvc.perform(get("/ceb007e9182/a.txt"))
                .andExpect(status().is2xxSuccessful())
                .andExpect(content().string(content));
    }

    @Test
    public void shouldRespondWith404IfFileNotFound() throws Exception {
        when(storageService.getFile(anyString(), anyString()))
                .thenThrow(new FileNotFoundException());

        this.mvc.perform(get("/ceb007e9182/a.txt"))
                .andExpect(status().isNotFound());
    }
}
