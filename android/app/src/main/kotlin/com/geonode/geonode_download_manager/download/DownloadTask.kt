package com.geonode.geonode_download_manager.download

data class DownloadTask(
    val gid: String,
    val url: String,
    var fileName: String,
    val directory: String,
    val split: Int,
    val headers: Map<String, String>,
    var status: String,
    var totalLength: Long,
    var completedLength: Long,
    var downloadSpeed: Long,
    var connections: Int,
    var pieceLength: Long,
    var numPieces: Int,
    var bitfield: String?,
    var errorMessage: String?,
    var contentUri: String?,
    var partPath: String?,
    var queuePosition: Int,
    val createdAt: Long,
    var updatedAt: Long,
) {
    fun toStatusMap(): Map<String, Any?> {
        val path = contentUri ?: partPath ?: ""
        return mapOf(
            "gid" to gid,
            "status" to status,
            "totalLength" to totalLength.toString(),
            "completedLength" to completedLength.toString(),
            "downloadSpeed" to downloadSpeed.toString(),
            "connections" to connections.toString(),
            "pieceLength" to pieceLength.toString(),
            "numPieces" to numPieces.toString(),
            "bitfield" to bitfield,
            "errorCode" to if (status == "error") "1" else null,
            "errorMessage" to errorMessage,
            "files" to listOf(
                mapOf(
                    "path" to path,
                    "length" to totalLength.toString(),
                    "completedLength" to completedLength.toString(),
                    "uris" to listOf(mapOf("uri" to url)),
                ),
            ),
        )
    }
}
