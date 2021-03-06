## set working dir to source file destination
# install packages if necessary. Limma is from bioclite.
library(readr)
library(readxl)
library(pheatmap)
library(RColorBrewer)
library(reshape2)
library(FactoMineR)
library(factoextra)
library(qgraph)
library(gplots)
library(cowplot)
library(tidyverse)
#if (!requireNamespace("BiocManager", quietly = TRUE))
#  install.packages("BiocManager")
#BiocManager::install("limma", version = "3.8")
library(limma)
####### Mature B vs Mature T comparison #######
rm(list = ls())
dat <- read.csv("input/GEO2R_downloads/4.MatureB_vs_matureT_20180128.csv",stringsAsFactors = F) 
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F) #curated gene list

## remove genes from genelist which are not in the microarray
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]

## select significance cutoff = 0.1
DE_genes <- dat[which(dat$adj.P.Val<0.1),]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
toplot <- DE_genes[,c(1,3,7,9)]
toplot <- toplot[!duplicated(toplot),]
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
df <- data.frame(DE_genes %>% count(Curated_pathway),genelist %>% count(Curated_pathway))
df <- df[,c(1,2,4)]
colnames(df) <- c("Pathway","Overlap","ngenes_genelist")
df$ngenes_not_genelist <- ngenes_universe - df$ngenes_genelist
df$ngenes_DEgenes <- rep(ngenes_DEgenes)
df$HG_test <- 1-phyper(df$Overlap-1,df$ngenes_genelist,df$ngenes_not_genelist,df$ngenes_DEgenes)
df$FDR <- p.adjust(df$HG_test, method = "fdr", n = nrow(df))
df$Enrichment <- (df$Overlap/df$ngenes_DEgenes)/(df$ngenes_genelist/(df$ngenes_genelist+df$ngenes_not_genelist))
write.csv(df,"output/Enrichment_BvsT.csv",row.names = F)

# plots for Figure
df <- df[order(df$FDR),]
df$Pathway <- factor(df$Pathway, levels= df$Pathway)
A<- ggplot(df,aes(Enrichment,-log(FDR),colour= Pathway))+
  geom_point(size=2,shape=1,stroke=1.2)+
  scale_x_continuous(limits = c(0.5,3))+
  scale_y_continuous(limits = c(0,4))+
  theme_linedraw()+
  theme(panel.grid = element_blank())+
  labs( x= "Enrichment score",
        y="Significance level (- log FDR)",
        legend = "Gene set",
        colour="Gene sets")+
  geom_hline(yintercept=-log(0.1))+
  geom_vline(xintercept=1)+
  annotate("text", label = "significance cut-off", x = 2, y = 2.45, size=3)+
  theme(axis.text = element_text(face = "bold", size=8))
A
pdf("output/Enrichment_BvsT.pdf", height = 4, width = 6)
A
dev.off()

## Plot heatmaps of enriched pathways
A <- toplot[which(toplot$Curated_pathway == "Mitochondrial membrane potential"),]
B <- toplot[which(toplot$Curated_pathway == "Protein synthesis"),]
C<- toplot[which(toplot$Curated_pathway == "TCA+OXPHOS"),]
D <- toplot[which(toplot$Curated_pathway == "Glycolysis"),]
E <- toplot[which(toplot$Curated_pathway == "ABC transporters"),]

B <- B[order(B$logFC),]
B <- B[c(1:10,nrow(B):(nrow(B)-9)),]

C <- C[order(C$logFC),]
C <- C[c(1:10,nrow(C):(nrow(C)-9)),]

rawdata <- read.csv("input/immgen_rawdata/B_vs_T_rawdata.csv")
rownames(rawdata)<- rawdata$NAME

A <- rawdata[which(rawdata$NAME %in% A$Gene.symbol),-1] 
B <- rawdata[which(rawdata$NAME %in% B$Gene.symbol),-1]
C <- rawdata[which(rawdata$NAME %in% C$Gene.symbol),-1]
D <- rawdata[which(rawdata$NAME %in% D$Gene.symbol),-1]
E <- rawdata[which(rawdata$NAME %in% E$Gene.symbol),-1]

## Define annotation colours
Col_annotation <- data.frame(row.names = colnames(A), Subsets = c(rep("B cell",3),rep("nCD4",3),rep("nCD8",3)))
Col_annotation$Subsets <- factor(Col_annotation$Subsets,levels = c("B cell","nCD4","nCD8"))
Subsets <- c("blue", "green","red")
names(Subsets) <- c("B cell","nCD4","nCD8")
anno_colors <- list(Subsets = Subsets)
#par(mfrow=c(2,3))
pdf("output/Heatmaps_BvsT.pdf", height = 5, width = 5)
pheatmap(A,
         scale = "row",
         annotation_col = Col_annotation,
         cellwidth = 9,cellheight = 9,
         fontsize = 7,
         main = "Mitochondrial membrane potential",show_colnames = F)

pheatmap(B,
         scale = "row",
         annotation_col = Col_annotation,
         cellwidth = 9,cellheight = 9,
         fontsize = 7,
         main = "Protein synthesis",show_colnames = F)
pheatmap(C,
         scale = "row",
         annotation_col = Col_annotation,
         cellwidth = 9,cellheight = 9,
         fontsize = 7,
         main = "TCA + OXPHOS",
         show_colnames = F)
pheatmap(D,
         scale = "row",
         annotation_col = Col_annotation,
         cellwidth = 9,cellheight = 9,
         fontsize = 7,
         main = "Glycolysis",
         show_colnames = F)
pheatmap(E,
         scale = "row",
         annotation_col = Col_annotation,
         cellwidth = 9,cellheight = 9,
         fontsize = 7,
         main = "ABC transporters",
         show_colnames = F)
dev.off()

rm(list = ls())

########## PCA analysis on all immgen subsets #############

dat <- read.csv("input/immgen_rawdata/immgen_subsets_rawdata.csv",stringsAsFactors = F)

h <- t(log(dat[,-1]))
h <- dist(h)
H <- hclust(h)

pdf("output/QC.pdf",width = 4.5,height=8)
par(mfrow=c(2,1))
boxplot(dat[,-1],use.cols=T,log="y",outline=F,ylab="Expression",las=2,cex.axis=0.7,cex.main=0.8,col="skyblue",main="Expression levels of all genes (quality control)")
plot(H,sub = NA,xlab = NA,cex=0.7,cex.axis=0.7,cex.main=0.8)
dev.off()

genes <- read.csv("input/curated_genelist/curated_genelist.csv")
dat <- dat[which(dat$GeneSymbol %in% genes$Genes),]
dat <- melt(dat)
dat <- dcast(dat, variable~GeneSymbol)
dat.log <- log(dat[,-1])
dat.pca <- PCA(dat.log, graph = FALSE,scale.unit = FALSE)
var <- get_pca_var(dat.pca)
ind <- get_pca_ind(dat.pca)
toplot_pca <- data.frame(Stage = dat$variable,ind$coord)
subsets <- data.frame(Stage=toplot_pca$Stage)
subsets$Subset <- c("Pro-B","Pro-B","Pro-B","Pre-B","Pre-B","Immature-B","Immature-B","Mature-B",
                    "DN","DN","DN","DN","DN","DP","SP","SP","Mature-T","Mature-T")
subsets$Subset <- factor(subsets$Subset, levels = c("Pro-B","Pre-B","Immature-B","Mature-B","DN","DP","SP","Mature-T"))
toplot_pca <- merge(toplot_pca,subsets, by= "Stage")
toplot_pca <- toplot_pca[order(toplot_pca$Subset),]
toplot_pca$Lineage <- c(rep("B-cells",8),rep("T-cells",10))
toplot_pca$Stages <- c(rep("Pro-B / DN",3),rep("Pre-B / DP",2),rep("Immature-B / SP",2),"Mature",
                       rep("Pro-B / DN",5),"Pre-B / DP",rep("Immature-B / SP",2),rep("Mature",2))
toplot_pca$Stages <- factor(toplot_pca$Stages,levels = c("Pro-B / DN","Pre-B / DP","Immature-B / SP","Mature"))
A<-ggplot(toplot_pca,aes(Dim.1,Dim.2))+
  geom_point(size=2,stroke=1.2,aes(colour = Lineage,shape=Stages))+
  scale_colour_manual(values=c("red","blue"))+
  labs(x="PC1",y="PC2")+
  theme_linedraw()+
  theme(panel.border = element_rect(colour = "black", fill=NA, size=1.2))+
  theme(panel.grid = element_blank())+
  coord_fixed(ratio = 1.5)
A

# Scree plot
B<-fviz_eig(dat.pca, addlabels = F,barfill = "skyblue",barcolor = "black",ylim=c(0,50))+
  ggtitle(" ")+
  theme_linedraw()+
  theme(panel.border = element_rect(colour = "black", fill=NA, size=1.2))+
  theme(panel.grid = element_blank())+
  coord_fixed(ratio = 0.25)
B

pdf("output/PCA.pdf",width = 8,height = 3.3)
plot_grid(A, B, labels="AUTO", nrow = 1)
dev.off()

# Response to reviewer: What does PC3 signify?
p1<-ggplot(toplot_pca,aes(Dim.1,Dim.3))+
  geom_point(size=2,stroke=1.2,aes(colour = Lineage,shape=Stages))+
  scale_colour_manual(values=c("red","blue"))+
  labs(x="PC1",y="PC3")+
  theme_linedraw()+
  theme(panel.border = element_rect(colour = "black", fill=NA, size=1.2))+
  theme(panel.grid = element_blank())+
  coord_fixed(ratio = 1.5)

p2<-ggplot(toplot_pca,aes(Dim.2,Dim.3))+
  geom_point(size=2,stroke=1.2,aes(colour = Lineage,shape=Stages))+
  scale_colour_manual(values=c("red","blue"))+
  labs(x="PC2",y="PC3")+
  theme_linedraw()+
  theme(panel.border = element_rect(colour = "black", fill=NA, size=1.2))+
  theme(panel.grid = element_blank())+
  coord_fixed(ratio = 1.5)

pdf("output/PCA_reviewer_comment.pdf",width = 5,height = 7)
plot_grid(p1, p2, labels="AUTO", nrow = 2)
dev.off()

# qgraph
dist_m <- as.matrix(dist(dat[,-1]))
dist_mi <- 1/dist_m # one over, as qgraph takes similarity matrices as input
Names <- subsets$Subset

pdf("output/qgraph.pdf",width = 3.3,height = 3.3)
tiff("output/qgraph.tiff",width = 3.3, height = 3.3, units = "in", res = 300,pointsize = 10)
qgraph(dist_mi, vsize=3,
       labels=FALSE,
       groups = Names,
       theme ="classic",
       legend.cex=0.5,
       layout='spring', 
       color= c("white", "yellow", "orange", "red", "blue", "green", "purple", "black"))
         #c(brewer.pal(n = 4, 'YlOrRd'),brewer.pal(4,"RdPu")))
dev.off()

## Extraction of PC1+2+3 genes
var_contrib <- var$contrib
var_contrib <- data.frame(genes=rownames(var_contrib),var_contrib)
var_contrib$genes <- as.character(var_contrib$genes)
rownames(var_contrib) <- 1:nrow(var_contrib)
ref_line <- 100/nrow(var_contrib)
PC1_genes <- var_contrib[which(var_contrib$Dim.1>ref_line),]
PC2_genes <- var_contrib[which(var_contrib$Dim.2>ref_line),]
PC3_genes <- var_contrib[which(var_contrib$Dim.3>ref_line),]
length(unique(PC1_genes$genes))
length(unique(PC2_genes$genes))
length(unique(PC3_genes$genes))
PCgenes<- unique(c(PC1_genes$genes,PC2_genes$genes,PC3_genes$genes))

genelists <- list(PC1 = PC1_genes$genes, PC2 = PC2_genes$genes,PC3 = PC3_genes$genes)

pdf("output/PCA_Venn1.pdf",width = 3.3,height = 3.3)
par(mar=c(0,0,0,0))
#tiff("Fig4E.tiff",width = 3,height = 3, units = "in", res = 300,pointsize = 10)
#par(mar=c(0,0,0,0))
venn(genelists)
dev.off()

#write.csv(PC1_genes,"output/PC1.csv",row.names = F)
#write.csv(PC2_genes,"output/PC2.csv",row.names = F )
#write.csv(PC3_genes,"output/PC3.csv",row.names = F)
genes_i <- intersect(intersect(PC1_genes$genes,PC2_genes$genes),PC3_genes$genes)
#write.csv(genes_i,"output/intersect_PC123.csv",row.names = F)

# Heatmap based on intersecting genes
dat <- read.csv("input/immgen_rawdata/immgen_subsets_rawdata.csv")
# colour palettes for heatmap
Col_annotation <- data.frame(row.names = colnames(dat)[-1], Subsets = subsets$Subset)
Subsets        <- c(brewer.pal(4,"Greens"),brewer.pal(4,"Purples"))
names(Subsets) <- c("Pro-B","Pre-B","Immature-B","Mature-B","DN","DP","SP","Mature-T")
anno_colors <- list(Subsets = Subsets)

toplot <- dat[which(dat$GeneSymbol %in% genes_i),]
toplot.log <- log(toplot[,-1])
rownames(toplot.log)<- toplot$GeneSymbol
pdf("output/Heatmap_PCAgenes.pdf",width = 6.9,height = 8.5)
pheatmap(toplot.log,
         scale = "row",
         cluster_cols = F, cluster_rows = T,
         annotation_col = Col_annotation,
         show_rownames = T,
         gaps_col=c(8),
         annotation_colors = anno_colors,
         color = rev(brewer.pal(10,"RdYlBu")),
         main = "Based on 38 genes that \n contributed to PC1+PC2+PC3",
         cutree_rows = 4,
         annotation_names_col  = F,
         fontsize_row  = 7,
         fontsize_col = 7,
         cellwidth = 7,cellheight = 7)
dev.off()

# comparing PC 1_2_3 genes with all DE genes

A1 <- read.csv("input/GEO2R_downloads/1.ProB_vs_DN_20180128.csv",stringsAsFactors = F)
A1 <- A1[which(A1$adj.P.Val<0.01),]
A1 <- A1[which(A1$Gene.symbol %in% genes$Genes),"Gene.symbol"]

A2 <- read.csv("input/GEO2R_downloads/2.PreB_vs_DP_20180128.csv",stringsAsFactors = F)
A2 <- A2[which(A2$adj.P.Val<0.01),]
A2 <- A2[which(A2$Gene.symbol %in% genes$Genes),"Gene.symbol"]

A3 <- read.csv("input/GEO2R_downloads/3.ImmatureB_vs_SP_20180128.csv",stringsAsFactors = F)
A3 <- A3[which(A3$adj.P.Val<0.01),]
A3 <- A3[which(A3$Gene.symbol %in% genes$Genes),"Gene.symbol"]

A4 <- read.csv("input/GEO2R_downloads/4.MatureB_vs_matureT_20180128.csv",stringsAsFactors = F)
A4 <- A4[which(A4$adj.P.Val<0.01),]
A4 <- A4[which(A4$Gene.symbol %in% genes$Genes),"Gene.symbol"]

A5 <- read.csv("input/GEO2R_downloads/5.ProB_vs_PreB_20180128.csv",stringsAsFactors = F)
A5 <- A5[which(A5$adj.P.Val<0.01),]
A5 <- A5[which(A5$Gene.symbol %in% genes$Genes),"Gene.symbol"]

A6 <- read.csv("input/GEO2R_downloads/6.PreB_vs_ImmatureB_20180128.csv",stringsAsFactors = F)
A6 <- A6[which(A6$adj.P.Val<0.01),]
A6 <- A6[which(A6$Gene.symbol %in% genes$Genes),"Gene.symbol"]

A7 <- read.csv("input/GEO2R_downloads/7.ImmatureB_vs_MatureB_20180128.csv",stringsAsFactors = F)
A7 <- A7[which(A7$adj.P.Val<0.01),]
A7 <- A7[which(A7$Gene.symbol %in% genes$Genes),"Gene.symbol"]

A8 <- read.csv("input/GEO2R_downloads/8.DN_vs_DP_20180128.csv",stringsAsFactors = F)
A8 <- A8[which(A8$adj.P.Val<0.01),]
A8 <- A8[which(A8$Gene.symbol %in% genes$Genes),"Gene.symbol"]

A9 <- read.csv("input/GEO2R_downloads/9.DP_vs_SP_20180128.csv",stringsAsFactors = F)
A9 <- A9[which(A9$adj.P.Val<0.01),]
A9 <- A9[which(A9$Gene.symbol %in% genes$Genes),"Gene.symbol"]

A10 <- read.csv("input/GEO2R_downloads/10.SP_vs_matureT_20180128.csv",stringsAsFactors = F)
A10 <- A10[which(A10$adj.P.Val<0.01),]
A10 <- A10[which(A10$Gene.symbol %in% genes$Genes),"Gene.symbol"]

A <- unique(c(A1,A2,A3,A4,A5,A6,A7,A8,A9,A10))
PC <- unique(c(PC1_genes$genes,PC2_genes$genes,PC3_genes$genes))

genelists <- list(`PCA genes` = PC, `Differentially expressed genes` = A)
pdf("output/PCA_Venn2.pdf",width = 3.3,height = 3.3)
#tiff("Fig4F.tiff",width = 3,height = 3, units = "in", res = 300,pointsize = 10)
par(mar=c(0,0,0,0))
venn(genelists)
legend(275,220,"P < 0.001",bty = "n")
dev.off()
1-phyper(576,1013,21755-1013,605)


########## Enrichment in pathways in DE genes across all lineages ##############
rm(list = ls())

## D1
dat <- read.csv("input/GEO2R_downloads/1.ProB_vs_DN_20180128.csv")
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F)
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]
DE_genes <- dat[order(dat$adj.P.Val),][1:4000,]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
Temp1 <- data.frame(genelist %>% count(Curated_pathway))
Temp2 <- data.frame(DE_genes %>% count(Curated_pathway))
Temp1<- merge(Temp1, Temp2,by="Curated_pathway",all.x = T)
D1 <- Temp1[,c(1,3,2)]
colnames(D1) <- c("Pathway","Overlap","ngenes_genelist")
D1$ngenes_not_genelist <- ngenes_universe - D1$ngenes_genelist
D1$ngenes_DEgenes <- rep(ngenes_DEgenes)
D1$HG_test <- 1-phyper(D1$Overlap-1,D1$ngenes_genelist,D1$ngenes_not_genelist,D1$ngenes_DEgenes)
D1$FDR <- p.adjust(D1$HG_test, method = "fdr", n = nrow(D1))
D1$Enrichment <- (D1$Overlap/D1$ngenes_DEgenes)/(D1$ngenes_genelist/(D1$ngenes_genelist+D1$ngenes_not_genelist))

## D2
dat <- read.csv("input/GEO2R_downloads/2.PreB_vs_DP_20180128.csv")
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F)
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]
DE_genes <- dat[order(dat$adj.P.Val),][1:4000,]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
Temp1 <- data.frame(genelist %>% count(Curated_pathway))
Temp2 <- data.frame(DE_genes %>% count(Curated_pathway))
Temp1<- merge(Temp1, Temp2,by="Curated_pathway",all.x = T)
D2 <- Temp1[,c(1,3,2)]
colnames(D2) <- c("Pathway","Overlap","ngenes_genelist")
D2$ngenes_not_genelist <- ngenes_universe - D2$ngenes_genelist
D2$ngenes_DEgenes <- rep(ngenes_DEgenes)
D2$HG_test <- 1-phyper(D2$Overlap-1,D2$ngenes_genelist,D2$ngenes_not_genelist,D2$ngenes_DEgenes)
D2$FDR <- p.adjust(D2$HG_test, method = "fdr", n = nrow(D2))
D2$Enrichment <- (D2$Overlap/D2$ngenes_DEgenes)/(D2$ngenes_genelist/(D2$ngenes_genelist+D2$ngenes_not_genelist))


## D3
dat <- read.csv("input/GEO2R_downloads/3.ImmatureB_vs_SP_20180128.csv")
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F)
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]
DE_genes <- dat[order(dat$adj.P.Val),][1:4000,]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
Temp1 <- data.frame(genelist %>% count(Curated_pathway))
Temp2 <- data.frame(DE_genes %>% count(Curated_pathway))
Temp1<- merge(Temp1, Temp2,by="Curated_pathway",all.x = T)
D3 <- Temp1[,c(1,3,2)]
colnames(D3) <- c("Pathway","Overlap","ngenes_genelist")
D3$ngenes_not_genelist <- ngenes_universe - D3$ngenes_genelist
D3$ngenes_DEgenes <- rep(ngenes_DEgenes)
D3$HG_test <- 1-phyper(D3$Overlap-1,D3$ngenes_genelist,D3$ngenes_not_genelist,D3$ngenes_DEgenes)
D3$FDR <- p.adjust(D3$HG_test, method = "fdr", n = nrow(D3))
D3$Enrichment <- (D3$Overlap/D3$ngenes_DEgenes)/(D3$ngenes_genelist/(D3$ngenes_genelist+D3$ngenes_not_genelist))

## D4
dat <- read.csv("input/GEO2R_downloads/4.MatureB_vs_matureT_20180128.csv")
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F)
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]
DE_genes <- dat[order(dat$adj.P.Val),][1:4000,]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
Temp1 <- data.frame(genelist %>% count(Curated_pathway))
Temp2 <- data.frame(DE_genes %>% count(Curated_pathway))
Temp1<- merge(Temp1, Temp2,by="Curated_pathway",all.x = T)
D4 <- Temp1[,c(1,3,2)]
colnames(D4) <- c("Pathway","Overlap","ngenes_genelist")
D4$ngenes_not_genelist <- ngenes_universe - D4$ngenes_genelist
D4$ngenes_DEgenes <- rep(ngenes_DEgenes)
D4$HG_test <- 1-phyper(D4$Overlap-1,D4$ngenes_genelist,D4$ngenes_not_genelist,D4$ngenes_DEgenes)
D4$FDR <- p.adjust(D4$HG_test, method = "fdr", n = nrow(D4))
D4$Enrichment <- (D4$Overlap/D4$ngenes_DEgenes)/(D4$ngenes_genelist/(D4$ngenes_genelist+D4$ngenes_not_genelist))


## B1
dat <- read.csv("input/GEO2R_downloads/5.ProB_vs_PreB_20180128.csv")
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F)
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]
DE_genes <- dat[order(dat$adj.P.Val),][1:4000,]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
Temp1 <- data.frame(genelist %>% count(Curated_pathway))
Temp2 <- data.frame(DE_genes %>% count(Curated_pathway))
Temp1<- merge(Temp1, Temp2,by="Curated_pathway",all.x = T)
B1 <- Temp1[,c(1,3,2)]
colnames(B1) <- c("Pathway","Overlap","ngenes_genelist")
B1$ngenes_not_genelist <- ngenes_universe - B1$ngenes_genelist
B1$ngenes_DEgenes <- rep(ngenes_DEgenes)
B1$HG_test <- 1-phyper(B1$Overlap-1,B1$ngenes_genelist,B1$ngenes_not_genelist,B1$ngenes_DEgenes)
B1$FDR <- p.adjust(B1$HG_test, method = "fdr", n = nrow(B1))
B1$Enrichment <- (B1$Overlap/B1$ngenes_DEgenes)/(B1$ngenes_genelist/(B1$ngenes_genelist+B1$ngenes_not_genelist))



## B2
dat <- read.csv("input/GEO2R_downloads/6.PreB_vs_ImmatureB_20180128.csv")
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F)
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]
DE_genes <- dat[order(dat$adj.P.Val),][1:4000,]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
Temp1 <- data.frame(genelist %>% count(Curated_pathway))
Temp2 <- data.frame(DE_genes %>% count(Curated_pathway))
Temp1<- merge(Temp1, Temp2,by="Curated_pathway",all.x = T)
B2 <- Temp1[,c(1,3,2)]
colnames(B2) <- c("Pathway","Overlap","ngenes_genelist")
B2$ngenes_not_genelist <- ngenes_universe - B2$ngenes_genelist
B2$ngenes_DEgenes <- rep(ngenes_DEgenes)
B2$HG_test <- 1-phyper(B2$Overlap-1,B2$ngenes_genelist,B2$ngenes_not_genelist,B2$ngenes_DEgenes)
B2$FDR <- p.adjust(B2$HG_test, method = "fdr", n = nrow(B2))
B2$Enrichment <- (B2$Overlap/B2$ngenes_DEgenes)/(B2$ngenes_genelist/(B2$ngenes_genelist+B2$ngenes_not_genelist))


## B3
dat <- read.csv("input/GEO2R_downloads/7.ImmatureB_vs_MatureB_20180128.csv")
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F)
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]
DE_genes <- dat[order(dat$adj.P.Val),][1:4000,]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
Temp1 <- data.frame(genelist %>% count(Curated_pathway))
Temp2 <- data.frame(DE_genes %>% count(Curated_pathway))
Temp1<- merge(Temp1, Temp2,by="Curated_pathway",all.x = T)
B3 <- Temp1[,c(1,3,2)]
colnames(B3) <- c("Pathway","Overlap","ngenes_genelist")
B3$ngenes_not_genelist <- ngenes_universe - B3$ngenes_genelist
B3$ngenes_DEgenes <- rep(ngenes_DEgenes)
B3$HG_test <- 1-phyper(B3$Overlap-1,B3$ngenes_genelist,B3$ngenes_not_genelist,B3$ngenes_DEgenes)
B3$FDR <- p.adjust(B3$HG_test, method = "fdr", n = nrow(B3))
B3$Enrichment <- (B3$Overlap/B3$ngenes_DEgenes)/(B3$ngenes_genelist/(B3$ngenes_genelist+B3$ngenes_not_genelist))



## T1
dat <- read.csv("input/GEO2R_downloads/8.DN_vs_DP_20180128.csv")
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F)
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]
DE_genes <- dat[order(dat$adj.P.Val),][1:4000,]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
Temp1 <- data.frame(genelist %>% count(Curated_pathway))
Temp2 <- data.frame(DE_genes %>% count(Curated_pathway))
Temp1<- merge(Temp1, Temp2,by="Curated_pathway",all.x = T)
T1 <- Temp1[,c(1,3,2)]
colnames(T1) <- c("Pathway","Overlap","ngenes_genelist")
T1$ngenes_not_genelist <- ngenes_universe - T1$ngenes_genelist
T1$ngenes_DEgenes <- rep(ngenes_DEgenes)
T1$HG_test <- 1-phyper(T1$Overlap-1,T1$ngenes_genelist,T1$ngenes_not_genelist,T1$ngenes_DEgenes)
T1$FDR <- p.adjust(T1$HG_test, method = "fdr", n = nrow(T1))
T1$Enrichment <- (T1$Overlap/T1$ngenes_DEgenes)/(T1$ngenes_genelist/(T1$ngenes_genelist+T1$ngenes_not_genelist))



## T2
dat <- read.csv("input/GEO2R_downloads/9.DP_vs_SP_20180128.csv")
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F)
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]
DE_genes <- dat[order(dat$adj.P.Val),][1:4000,]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
Temp1 <- data.frame(genelist %>% count(Curated_pathway))
Temp2 <- data.frame(DE_genes %>% count(Curated_pathway))
Temp1<- merge(Temp1, Temp2,by="Curated_pathway",all.x = T)
T2 <- Temp1[,c(1,3,2)]
colnames(T2) <- c("Pathway","Overlap","ngenes_genelist")
T2$ngenes_not_genelist <- ngenes_universe - T2$ngenes_genelist
T2$ngenes_DEgenes <- rep(ngenes_DEgenes)
T2$HG_test <- 1-phyper(T2$Overlap-1,T2$ngenes_genelist,T2$ngenes_not_genelist,T2$ngenes_DEgenes)
T2$FDR <- p.adjust(T2$HG_test, method = "fdr", n = nrow(T2))
T2$Enrichment <- (T2$Overlap/T2$ngenes_DEgenes)/(T2$ngenes_genelist/(T2$ngenes_genelist+T2$ngenes_not_genelist))



## T3
dat <- read.csv("input/GEO2R_downloads/10.SP_vs_matureT_20180128.csv")
ngenes_universe <- length(unique(dat$Gene.symbol))
genelist <- read.csv("input/curated_genelist/curated_genelist.csv",stringsAsFactors = F)
length(setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # number of genes in gene list that are not in microarray
genelist <- filter(genelist, !Genes %in% setdiff(unique(genelist$Genes),unique(dat$Gene.symbol))) # these genes need to be removed from gene list
genelist <- genelist[,c(1,2)] # we need only the curated pathway
genelist <- genelist[!duplicated(genelist),]
DE_genes <- dat[order(dat$adj.P.Val),][1:4000,]
ngenes_DEgenes <- length(unique(DE_genes$Gene.symbol))
DE_genes <- DE_genes[which(DE_genes$Gene.symbol %in% genelist$Genes),]
DE_genes <- merge(DE_genes,genelist,by.x = "Gene.symbol",by.y = "Genes")
DE_genes <- DE_genes[,c(1,9)]
DE_genes<-DE_genes[!duplicated(DE_genes),]
Temp1 <- data.frame(genelist %>% count(Curated_pathway))
Temp2 <- data.frame(DE_genes %>% count(Curated_pathway))
Temp1<- merge(Temp1, Temp2,by="Curated_pathway",all.x = T)
T3 <- Temp1[,c(1,3,2)]
colnames(T3) <- c("Pathway","Overlap","ngenes_genelist")
T3$ngenes_not_genelist <- ngenes_universe - T3$ngenes_genelist
T3$ngenes_DEgenes <- rep(ngenes_DEgenes)
T3$HG_test <- 1-phyper(T3$Overlap-1,T3$ngenes_genelist,T3$ngenes_not_genelist,T3$ngenes_DEgenes)
T3$FDR <- p.adjust(T3$HG_test, method = "fdr", n = nrow(T3))
T3$Enrichment <- (T3$Overlap/T3$ngenes_DEgenes)/(T3$ngenes_genelist/(T3$ngenes_genelist+T3$ngenes_not_genelist))

##
T1[which(T1$FDR>0.1),8] <- rep(NA)
T2[which(T2$FDR>0.1),8] <- rep(NA)
T3[which(T3$FDR>0.1),8] <- rep(NA)

B1[which(B1$FDR>0.1),8] <- rep(NA)
B2[which(B2$FDR>0.1),8] <- rep(NA)
B3[which(B3$FDR>0.1),8] <- rep(NA)

D1[which(D1$FDR>0.1),8] <- rep(NA)
D2[which(D2$FDR>0.1),8] <- rep(NA)
D3[which(D3$FDR>0.1),8] <- rep(NA)
D4[which(D4$FDR>0.1),8] <- rep(NA)

T1[which(T1$Enrichment<=1),8] <- rep(NA)
T2[which(T2$Enrichment<=1),8] <- rep(NA)
T3[which(T3$Enrichment<=1),8] <- rep(NA)

B1[which(B1$Enrichment<=1),8] <- rep(NA)
B2[which(B2$Enrichment<=1),8] <- rep(NA)
B3[which(B3$Enrichment<=1),8] <- rep(NA)

D1[which(D1$Enrichment<=1),8] <- rep(NA)
D2[which(D2$Enrichment<=1),8] <- rep(NA)
D3[which(D3$Enrichment<=1),8] <- rep(NA)
D4[which(D4$Enrichment<=1),8] <- rep(NA)

##
lineage <- data.frame(D1$Pathway,D1$Enrichment, D2$Enrichment, D3$Enrichment, D4$Enrichment)
colnames(lineage) <- c("Pathway","Pro-B vs DN-T",
                       "Pre-B vs DP-T", "Immature-B vs SP-T",
                       "Mature-B vs Mature-T") 
lineage
rownames(lineage) <- lineage$Pathway

pdf("output/Between_lineage.pdf",width = 5.5,height = 5)
#tiff("Fig4F.tiff",width = 4.5,height = 4.2, units = "in", res = 300,pointsize = 10)
pheatmap((lineage[,-1]),
         cluster_cols = F, cluster_rows = F,
         show_rownames = T,
         color = brewer.pal(9,"Reds"),
         main = "Between-\nlineage",
         fontsize_col = 10,
         fontsize_row = 10,
         cellwidth = 20,cellheight = 20)
dev.off()

Developm <- data.frame(B2$Pathway,B1$Enrichment,B2$Enrichment, B3$Enrichment, 
                       T1$Enrichment,T2$Enrichment,T3$Enrichment)
colnames(Developm) <- c("Pathway","Pro-B vs Pre-B",
                        "Pre-B vs Immature-B", 
                        "Immature-B vs Mature-B",
                        "DN-T vs DP-T",
                        "DP-T vs SP-T", 
                        "SP-T vs Mature-T")  
Developm
rownames(Developm) <- Developm$Pathway

pdf("output/Across_devt_stage.pdf",width = 5.5,height = 5)
#tiff("Fig4G.tiff",width = 5.5,height = 4.2, units = "in", res = 300,pointsize = 10)
pheatmap(Developm[,-1],
         cluster_cols = F, cluster_rows = F,
         show_rownames = T,
         color = brewer.pal(9,"Reds"),
         main = "Across- \ndevelopmental stages",
         fontsize_col = 10,
         fontsize_row = 10,
         gaps_col = c(3),
         cellwidth = 20,cellheight = 20)
dev.off()
write.csv(lineage,"output/Between_lineage.csv",row.names = F)
write.csv(Developm,"output/Across_devt_stage.csv",row.names = F)

######### AIF data analysis ##########


# Pearson correlation coefficient of top 100 differentially expressed
# genes against Aifm1 was calculated using Immuno-navigator for 
# B cell, CD4 and CD8 T cell lineages. 
B <- read.delim("input/Aif_correlations/Bcell.txt") # PCC of Aifm1 with top 100 B cell genes  in B cells
Ball <- read.delim("input/Aif_correlations/Bcell_all.txt") # PCC of Aifm1 with all genes in B cells
Ball$target.gene <- toupper(Ball$target.gene)
B_noninput <- Ball[which(!Ball$target.gene %in% B$input.list) ,] # rest of genes

plot(ecdf(B$Pearson.correlation.with.query.gene),
     xlim=c(-0.8,0.8),
     main="B cell",pch=20,
     xlab="PCC",ylab="Cumulative fraction")
lines(ecdf(B_noninput$Score),col="red")
legend( -0.85,0.99, 
        legend=c("top 100 B cell genes","rest of genes"),
        col=c("black","red"), lwd=1, lty=c(0,0), bty="n",
        pch=c(19,19))

# similarly, for CD4
CD4 <- read.delim("input/Aif_correlations/CD4.txt")
CD4all <- read.delim("input/Aif_correlations/CD4_all.txt")
CD4all$target.gene <- toupper(CD4all$target.gene)
CD4_noninput <- CD4all[which(!CD4all$target.gene %in% CD4$input.list) ,]
plot(ecdf(CD4$Pearson.correlation.with.query.gene),
     xlim=c(-0.8,0.8),
     main="CD4 T cell", pch=20,
     xlab="PCC",ylab="Cumulative fraction")
lines(ecdf(CD4_noninput$Score),col="red")
legend( -0.85,0.99,
        legend=c("top 100 T cell genes","rest of genes"),
        col=c("black","red"), lwd=1, lty=c(0,0), bty="n",
        pch=c(19,19) )

# and finally, for CD8
CD8 <- read.delim("input/Aif_correlations/CD8.txt")
CD8all <- read.delim("input/Aif_correlations/CD8_all.txt")
CD8all$target.gene <- toupper(CD8all$target.gene)
CD8_noninput <- CD8all[which(!CD8all$target.gene %in% CD8$input.list) ,]
plot(ecdf(CD8$Pearson.correlation.with.query.gene),
     xlim=c(-0.8,0.8),
     main="CD8 T cell",
     xlab="PCC",ylab="Cumulative fraction")
lines(ecdf(CD8_noninput$Score),col="red")
legend( -0.85,0.99, 
        legend=c("top 100 T cell genes","rest of genes"),
        col=c("black","red"), lwd=1, lty=c(0,0), bty="n",
        pch=c(19,19) )

## gene set enrichment using limma package ##
B <- read.delim("input/Aif_correlations/Bcell.txt")
Ball <- read.delim("input/Aif_correlations/Bcell_all.txt")
Ball$target.gene <- toupper(Ball$target.gene)
Ball$geneset <- Ball$target.gene %in% B$input.list
Ball$not_geneset <- !Ball$target.gene %in% B$input.list
barcodeplot(Ball$Score, Ball$geneset, 
            xlab = "PCC",
            main="B cell")


CD4 <- read.delim("input/Aif_correlations/CD4.txt")
CD4all <- read.delim("input/Aif_correlations/CD4_all.txt")
CD4all$target.gene <- toupper(CD4all$target.gene)
CD4all$geneset <- CD4all$target.gene %in% CD4$input.list
CD4all$not_geneset <- !CD4all$target.gene %in% CD4$input.list

barcodeplot(CD4all$Score, CD4all$geneset,
            xlab = "PCC",
            main="CD4 T cell")

CD8 <- read.delim("input/Aif_correlations/CD8.txt")
CD8all <- read.delim("input/Aif_correlations/CD8_all.txt")
CD8all$target.gene <- toupper(CD8all$target.gene)
CD8all$geneset <- CD8all$target.gene %in% CD8$input.list
CD8all$not_geneset <- !CD8all$target.gene %in% CD8$input.list
barcodeplot(CD8all$Score, CD8all$geneset,
            xlab = "PCC",
            main="CD8 T cell")


Ball$RANK <- rank(Ball$Score)
CD4all$RANK <- rank(CD4all$Score)
CD8all$RANK <- rank(CD8all$Score)

Brank <- Ball[which(Ball$geneset == TRUE),"RANK"]
CD4rank <- CD4all[which(CD4all$geneset == TRUE),"RANK"]
CD8rank <- CD8all[which(CD8all$geneset == TRUE),"RANK"]

#hist(Brank)
#hist(CD4rank)
#hist(CD8rank)

plot(density(CD4rank), 
     main="Density histograms - rank of PCC",
     xlab = "Rank of genes ordered by PCC",
     xlim=c(0,25000))
lines(density(CD8rank),col="blue")
lines(density(Brank),col="red")
legend( 1000,9e-05, 
        legend=c("CD4 T cell","CD8 T cell","B cell"),
        col=c("black","blue","red"), lwd=1, lty=c(0,0), bty="n",
        pch=c(19,19) )


mean(Brank)
mean(CD4rank)
t.test(Brank, CD4rank)
t.test(Brank,CD8rank)
df <- data.frame(B = c(Brank,NA,NA,NA),
                 CD4=CD4rank)

boxplot(Brank,CD4rank, boxwex = 0.3,notch = T, col="skyblue",
        main="Rank of PCC with Aifm1", ylab="Rank of genes")
axis(side = 1, labels = c("B cells","CD4 T cells"), at=c(1,2))
text(1.5,15000,"p = 4.4e-06")

boxplot(Brank,CD8rank, boxwex = 0.3,notch = T, col="skyblue",
        main="Rank of PCC with Aifm1", ylab="Rank of genes")
axis(side = 1, labels = c("B cells","CD8 T cells"), at=c(1,2))
text(1.5,15000,"p = 0.003")

# PLOTS 

pdf("output/Aif_correlations.pdf",width = 8.2,height = 10)
par(mfrow = c(3,3), omi=c(0.2,0.2,0.2,0.2))
plot(ecdf(B$Pearson.correlation.with.query.gene),
     xlim=c(-0.8,0.8),
     main="B cell",pch=20,
     xlab="PCC",ylab="Cumulative fraction")
lines(ecdf(B_noninput$Score),col="red")
legend( -0.9,0.99, 
        legend=c("top 100 B cell genes","rest of genes"),
        col=c("black","red"), lwd=1, lty=c(0,0), bty="n",
        pch=c(19,19))

plot(ecdf(CD4$Pearson.correlation.with.query.gene),
     xlim=c(-0.8,0.8),
     main="CD4 T cell", pch=20,
     xlab="PCC",ylab="Cumulative fraction")
lines(ecdf(CD4_noninput$Score),col="red")
legend( -0.9,0.99,
        legend=c("top 100 T cell genes","rest of genes"),
        col=c("black","red"), lwd=1, lty=c(0,0), bty="n",
        pch=c(19,19) )

plot(ecdf(CD8$Pearson.correlation.with.query.gene),
     xlim=c(-0.8,0.8),
     main="CD8 T cell",
     xlab="PCC",ylab="Cumulative fraction")
lines(ecdf(CD8_noninput$Score),col="red")
legend( -0.9,0.99, 
        legend=c("top 100 T cell genes","rest of genes"),
        col=c("black","red"), lwd=1, lty=c(0,0), bty="n",
        pch=c(19,19) )

barcodeplot(Ball$Score, Ball$geneset, 
            xlab = "PCC",
            main="B cell")
barcodeplot(CD4all$Score, CD4all$geneset,
            xlab = "PCC",
            main="CD4 T cell")
barcodeplot(CD8all$Score, CD8all$geneset,
            xlab = "PCC",
            main="CD8 T cell")



boxplot(Brank,CD4rank, boxwex = 0.3,notch = T, col="skyblue",
        main="Rank of PCC with Aifm1", ylab="Rank of genes")
axis(side = 1, labels = c("B cells","CD4 T cells"), at=c(1,2))
text(1.5,15000,"p = 4.4e-06")

boxplot(Brank,CD8rank, boxwex = 0.3,notch = T, col="skyblue",
        main="Rank of PCC with Aifm1", ylab="Rank of genes")
axis(side = 1, labels = c("B cells","CD8 T cells"), at=c(1,2))
text(1.5,15000,"p = 0.003")
dev.off()

# Reviewer question:
# The reviewer had asked the nature of PC1, PC2 and PC3 genes.
# To address this, I did a GO enrichment on gorilla using PC1, PC2 or PC3 genes as the input and all the metabolic genes (~1500 genes) in the genelist as the background.
# Input genes were PC1 genes, PC2 genes and PC3 genes from Table S6. Background genes were all the metabolism genes in the genelist in the 'input' folder.

rm(list = ls())

library(readxl)

# setwd("")

PC1 <- read_excel("input/PC1_PC2_PC3_enrichment/PC1.xlsx")
PC1 <- PC1[which(PC1$`FDR q-value`<0.05),]
PC1$PC <- rep("PC1")

PC2 <- read_excel("input/PC1_PC2_PC3_enrichment/PC2.xlsx")
PC2 <- PC2[which(PC2$`FDR q-value`<0.05), ]
PC2$PC <- rep("PC2")

PC3 <- read_excel("input/PC1_PC2_PC3_enrichment/PC3.xlsx")
PC3 <- PC3[which(PC3$`FDR q-value`<0.05),]
PC3$PC <- rep("PC3")


PC <- rbind(PC1, PC2, PC3)
PC <- PC[, c(6, 1:5)]

write.csv(PC, "output/PC123_enrichment.csv", row.names = F)


