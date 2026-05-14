tx_idx <- txdb@unlistData
tx_idx <- tx_idx$tx_id
tx_idx <- unique(tx_idx)
write.table(tx_idx[1:floor(length(tx_idx)/2)], file = "tmp/human_txids_1.txt", row.names = FALSE, col.names = FALSE, quote = FALSE)


write.table(tx_idx[floor(length(tx_idx)/2)+1:length(tx_idx)], file = "tmp/human_txids_2.txt", row.names = FALSE, col.names = FALSE, quote = FALSE)

#For mice
organism <- "mouse"
organism_data <- loadOrganismData(organism)
txdb_mice <- organism_data$txdb
tx_idx_mice <- unique(txdb_mice@unlistData$tx_id)


write.table(tx_idx_mice[1:floor(length(tx_idx_mice)/2)], file = "mapping/mouse/mouse_txids_1.txt", row.names = FALSE, col.names = FALSE, quote = FALSE)
write.table(tx_idx_mice[floor(length(tx_idx_mice)/2)+1:length(tx_idx_mice)], file = "mapping/mouse/mouse_txids_2.txt", row.names = FALSE, col.names = FALSE, quote = FALSE)
