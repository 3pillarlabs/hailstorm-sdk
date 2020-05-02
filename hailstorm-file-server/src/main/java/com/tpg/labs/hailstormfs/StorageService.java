package com.tpg.labs.hailstormfs;

import org.springframework.core.io.Resource;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Path;
import java.util.stream.Stream;

public interface StorageService {

    /**
     * Saves the file to storage.
     *
     * @param fileMetaData
     * @param fileTransferDelegate
     * @return stored file URI
     * @throws IOException
     */
    String saveFile(FileMetaData fileMetaData, FileTransferDelegate fileTransferDelegate) throws IOException;

    /**
     * Saves the file to storage with a <code>tag</code> directory.
     *
     * @param fileMetaData
     * @param fileTransferDelegate
     * @param tag
     * @return
     * @throws IOException
     */
    String saveFile(FileMetaData fileMetaData,
                    FileTransferDelegate fileTransferDelegate,
                    String tag) throws IOException;

    /**
     * Delete a file
     *
     * @param fileId
     * @throws IOException
     */
    void deleteFile(String fileId) throws IOException;

    /**
     * Delete a tagged file.
     *
     * @param fileId
     * @param tag
     * @throws IOException
     */
    void deleteFile(String fileId, String tag) throws IOException;

    /**
     * Get a file by Id and name
     *
     * @param fileId
     * @param fileName
     * @return
     * @throws FileNotFoundException
     */
    Resource getFile(String fileId, String fileName) throws FileNotFoundException;

    /**
     * Removes all files with given prefix.
     *
     * @param prefix
     */
    void removeFilesWithPrefix(String prefix) throws IOException;

    /**
     * Stream the paths matching a prefix.
     *
     * @param prefix
     * @return
     */
    Stream<Path> listPaths(String prefix);

    /**
     * Select paths that match the given tag.
     *
     * @param prefix
     * @param tag
     * @return
     */
    Stream<Path> listPaths(String prefix, String tag);
}
