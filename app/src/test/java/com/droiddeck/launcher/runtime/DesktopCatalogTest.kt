package com.droiddeck.launcher.runtime

import com.droiddeck.launcher.BuildConfig
import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class DesktopCatalogTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun desktopNeedsTheCompleteCurrentPinnedPackage() {
        val root = temporary.root
        val shell = File(root, "usr/bin/kalyna-shell").apply {
            parentFile.mkdirs()
            writeText("fixture")
        }
        val marker = File(root, ".droiddeck-pkg-${DesktopCatalog.DESKTOP_ID}")
        assertFalse(DesktopCatalog.desktopInstalled(root))
        marker.writeText("older-package")
        assertFalse(DesktopCatalog.desktopInstalled(root))
        marker.writeText("${BuildConfig.KALYNA_TAG}\n")
        assertTrue(DesktopCatalog.desktopInstalled(root))
        val pending = File(root, DesktopRemoval.PENDING).apply { writeText(BuildConfig.KALYNA_TAG) }
        assertFalse(DesktopCatalog.desktopInstalled(root))
        pending.delete()
        assertTrue(DesktopCatalog.desktopInstalled(root))
        shell.delete()
        assertFalse(DesktopCatalog.desktopInstalled(root))
    }
}
