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

@Controller
public class HailstormFsController {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());
    private final StorageService storageService;

    @Autowired
    public HailstormFsController(StorageService storageService) {
        this.storageService = storageService;
    }

    @PostMapping("/upload")
    public ResponseEntity<FileMetaData> uploadFile(@RequestParam("file") MultipartFile file) throws IOException {
        FileMetaData fileMetaData = new FileMetaData(
                file.getOriginalFilename(),
                file.getContentType(),
                file.getSize(),
                file.getInputStream());

        logger.debug("fileMetaData: {}", fileMetaData);
        String path = storageService.saveFile(fileMetaData, file::transferTo);
        return ResponseEntity.ok().body(fileMetaData.withId(path));
    }

    @DeleteMapping("/{fileId}")
    public ResponseEntity deleteFile(@PathVariable("fileId") String fileId) {
        logger.debug("path: {}", fileId);
        storageService.deleteFile(fileId);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/{fileId}/{fileName}")
    @ResponseBody
    public ResponseEntity<Resource> serveFile(@PathVariable("fileId") String fileId,
                                              @PathVariable("fileName") String fileName) {
        logger.debug("fileId: {}, fileName: {}", fileId, fileName);
        Resource file = null;
        try {
            file = storageService.getFile(fileId, fileName);
        } catch (FileNotFoundException e) {
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + fileName + "\"")
                .body(file);
    }
}
