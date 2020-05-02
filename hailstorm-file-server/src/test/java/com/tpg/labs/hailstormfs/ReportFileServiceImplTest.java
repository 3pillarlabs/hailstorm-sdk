package com.tpg.labs.hailstormfs;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.junit.jupiter.SpringExtension;

import java.io.ByteArrayInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.*;

@ExtendWith(SpringExtension.class)
class ReportFileServiceImplTest {

    @MockBean
    private StorageService storageService;

    ReportFileService reportFileService;

    @BeforeEach
    void createServiceInstance() {
        reportFileService = new ReportFileServiceImpl(storageService);
    }

    @Test
    void shouldDelegateSaveFileToStorageService() throws IOException {
        final String prefix = "project_code";
        final String content = "Hello, World";
        FileMetaData fileMetaData = new FileMetaData(
                "a.txt",
                "text/plain",
                (long) content.length(),
                new ByteArrayInputStream(content.getBytes())).withPathPrefix(prefix);

        FileTransferDelegate fileTransferDelegate = mock(FileTransferDelegate.class);
        reportFileService.saveFile(fileMetaData, fileTransferDelegate);
        verify(storageService).saveFile(fileMetaData, fileTransferDelegate, ReportFileServiceImpl.REPORTS_TAG);
    }

    @Test
    void shouldSelectReportsForPrefix() throws IOException {
        final ReportMetaData expRprtMetaData = new ReportMetaData("1", "a.docx");
        final Path reportPath = Paths.get("a", "reports", expRprtMetaData.getId(), expRprtMetaData.getTitle());
        when(storageService.listPaths(anyString(), anyString())).thenReturn(Stream.of(reportPath));

        List<ReportMetaData> reportMetaDataList = reportFileService.getReportMetaDataList("cuckoo");
        assertEquals(expRprtMetaData, reportMetaDataList.get(0));
    }

    @Test
    void shouldDelegateGetReportToStorageService() throws FileNotFoundException {
        final String fileId = "1", fileName = "a.docx";
        reportFileService.getReport(fileId, fileName);
        verify(storageService).getFile(fileId, fileName);
    }
}