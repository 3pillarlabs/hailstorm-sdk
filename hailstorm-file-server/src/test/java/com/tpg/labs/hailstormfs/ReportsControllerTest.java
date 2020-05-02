package com.tpg.labs.hailstormfs;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Arrays;

import static org.hamcrest.Matchers.is;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ReportsControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private StorageService storageService;

    @MockBean
    private ReportFileService reportFileService;

    @Test
    void shouldUploadFile() throws Exception {
        when(reportFileService.saveFile(any(FileMetaData.class), any(FileTransferDelegate.class)))
                .thenReturn("1234");

        MockMultipartFile multipartFile = new MockMultipartFile(
                "file",
                "report.docx",
                "application/octet-stream",
                "ABCD".getBytes()
        );

        mvc.perform(multipart("/reports")
                .file(multipartFile).param("prefix", "cuckoo"))
                .andDo(print())
                .andExpect(status().is2xxSuccessful())
                .andExpect(jsonPath("$.id", is("1234")));
    }

    @Test
    void shouldGetProjectReports() throws Exception{
        when(reportFileService.getReportMetaDataList(anyString()))
                .thenReturn(Arrays.asList(
                        new ReportMetaData("123", "a.docx"),
                        new ReportMetaData("234", "b.docx")
                ));

        mvc.perform(get("/reports/prefix"))
                .andDo(print())
                .andExpect(status().is2xxSuccessful());
    }
}