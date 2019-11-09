package com.tpg.labs.hailstormfs;

import java.io.File;
import java.io.IOException;

public interface FileTransferActor {

    void doTransfer(File dest) throws IOException;
}
