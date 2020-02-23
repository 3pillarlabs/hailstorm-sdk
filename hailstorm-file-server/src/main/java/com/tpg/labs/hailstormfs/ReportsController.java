package com.tpg.labs.hailstormfs;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.List;

@Controller
public class ReportsController {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());
    private final ReportFileService reportFileService;

    @Autowired
    public ReportsController(ReportFileService reportFileService) {
        this.reportFileService = reportFileService;
    }

    @PostMapping("/reports")
    public ResponseEntity<FileMetaData> uploadFile(@RequestParam("file") MultipartFile file,
                                                   @RequestParam("prefix") String pathPrefix) throws IOException {

        final FileMetaData fileMetaData = FileMetaDataBuilder.build(file, pathPrefix);
        logger.debug("fileMetaData: {}", fileMetaData);
        String path = reportFileService.saveFile(fileMetaData, file::transferTo);
        return ResponseEntity.ok().body(fileMetaData.withId(path));
    }

    @GetMapping("/reports/{prefix}")
    public ResponseEntity<List<ReportMetaData>> getProjectReports(
            @PathVariable("prefix") String prefix) throws IOException {

        List<ReportMetaData> reports = reportFileService.getReportMetaDataList(prefix);
        return ResponseEntity.ok().body(reports);
    }

    @GetMapping("/reports/{prefix}/{fileId}/{fileName}")
    @ResponseBody
    public ResponseEntity<Resource> serveFile(@PathVariable("prefix") String prefix,
                                              @PathVariable("fileId") String fileId,
                                              @PathVariable("fileName") String fileName) {

        Resource file = null;
        try {
            file = reportFileService.getReport(prefix, fileId, fileName);
        } catch (FileNotFoundException e) {
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + fileName + "\"")
                .body(file);
    }
}
