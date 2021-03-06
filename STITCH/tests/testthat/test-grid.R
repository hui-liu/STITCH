n_snps <- 5
chr <- 1

phasemaster <- matrix(c(rep(0, n_snps), rep(1, n_snps)), ncol = 2)
data_package <- make_acceptance_test_data_package(
    n_samples = 10,
    n_snps = n_snps,
    n_reads = 4,
    seed = 1,
    chr = chr,
    K = 2,
    phasemaster = phasemaster
)



test_that("can validate gridWindowSize", {
    expect_null(validate_gridWindowSize(as.numeric(1000)))
    expect_null(validate_gridWindowSize(as.integer(1000)))    
    expect_null(validate_gridWindowSize(10))    
    expect_null(validate_gridWindowSize(3))
    expect_null(validate_gridWindowSize(NA))    
    expect_error(validate_gridWindowSize(1))
    expect_error(validate_gridWindowSize(10.5))    
    expect_error(validate_gridWindowSize("1000"))
})

test_that("can assign physical positions to grid", {

    out <- assign_positions_to_grid(
        L = c(1, 10, 11, 20),
        gridWindowSize = 10
    )
    expect_equal(out$grid, c(0, 0, 1, 1))
    expect_equal(out$grid_distances, 10)
    expect_equal(out$L_grid, c(5, 15))
    expect_equal(out$nGrids, 2)

})

test_that("distances on the grid are OK", {

    out <- assign_positions_to_grid(
        L = 1e6 + c(1, 15456, 95123),
        gridWindowSize = 1e4
    )
    expect_equal(out$grid, c(0, 1, 2))
    expect_equal(out$grid_distances, c(1e4, 8 * 1e4))
    expect_equal(out$L_grid, 1e6 + c(5000, 15000, 95000))
    expect_equal(out$nGrids, 3)

})



test_that("removal of buffer from grid makes sense", {

    L <- 1:20
    n_snps <- 20
    regionStart <- 5
    regionEnd <- 16
    buffer <- 5
    K <- 4

    for(gridWindowSize in c(NA, 1, 3)) {
        
        out <- assign_positions_to_grid(
            L = L,
            gridWindowSize = gridWindowSize
        )
    
        alphaMatCurrent <- array(0, c(out$nGrids, K))
        
        out <- remove_buffer_from_variables(
            L = L,
            regionStart = regionStart,
            regionEnd = regionEnd,
            grid = out$grid,
            grid_distances = out$grid_distances,
            alphaMatCurrent = alphaMatCurrent,
            L_grid = out$L_grid,
            nGrids = out$nGrids,
            gridWindowSize = gridWindowSize,
            verbose = FALSE
        )
        
        expect_equal(length(out$grid), length(regionStart:regionEnd))
        ## 5-6, 7-9, 10-12, 13-15, 16
        if (is.na(gridWindowSize) == FALSE) {
            if (gridWindowSize == 3) {
                expect_equal(out$nGrids, 5)
                expect_equal(out$grid_distances, rep(gridWindowSize, 4)) ## no spacing
                expect_equal(out$L_grid, 4.5 + 3 * 0:4)
                expect_equal(nrow(out$alphaMatCurrent), 4)
            }
        }
        
    }
        

})




test_that("can use grid", {

    n_snps <- 10 ## set to 10000 to check times better
    K <- 20

    phasemaster <- matrix(
        c(rep(0, n_snps), rep(1, n_snps)),
        ncol = K
    )
    data_package <- make_acceptance_test_data_package(
        n_samples = 1,
        n_snps = n_snps,
        n_reads = n_snps * 2,
        seed = 2,
        chr = 10,
        K = K,
        phasemaster = phasemaster,
        reads_span_n_snps = 3,
        n_cores = 1
    )

    regionName <- "region-name"
    loadBamAndConvert(
        iBam = 1,
        L = data_package$L,
        pos = data_package$pos,
        nSNPs = data_package$nSNPs,
        bam_files = data_package$bam_files,
        N = 1,
        sampleNames = data_package$sample_names,
        inputdir = tempdir(),
        regionName = regionName,
        tempdir = tempdir(),
        chr = data_package$chr,
        chrStart = 1,
        chrEnd = max(data_package$pos[, 2]) + 100
    )

    load(file_sampleReads(tempdir(), 1, regionName))
    L <- data_package$pos[, 2]
    eHaps <- array(runif(n_snps * K), c(n_snps, K))

    ## for now, based on physical position?
    gridWindowSize <- 3
    out <- assign_positions_to_grid(L, gridWindowSize)
    grid <- out$grid
    nGrids <- out$nGrids
    sigma <- runif(nGrids - 1)
    alphaMat <- array(runif((nGrids - 1) * K), c(nGrids - 1, K))
    x <- sigma
    transMatRate <- cbind(x ** 2, x * (1 - x), (1 - x) ** 2)
    pi <- runif(K) / K

    ## also, update?
    sampleReads <- snap_sampleReads_to_grid(sampleReads, grid)

    transMatRate_t <- get_transMatRate(
        method = "diploid",
        sigmaCurrent = sigma
    )
    
    out <- forwardBackwardDiploid(
        sampleReads = sampleReads,
        nReads = as.integer(length(sampleReads)),
        pi = pi,
        transMatRate = transMatRate_t,
        alphaMat = t(alphaMat),
        eHaps = t(eHaps),
        maxDifferenceBetweenReads = as.double(1000),
        whatToReturn = as.integer(0),
        Jmax = as.integer(10),
        suppressOutput = as.integer(1)
    )

    pRgivenH1L <- runif(length(sampleReads))
    pRgivenH2L <- runif(length(sampleReads))

    transMatRate_t <- get_transMatRate(
        method = "pseudoHaploid",
        sigmaCurrent = sigma
    )

    out <- forwardBackwardHaploid(
        sampleReads = sampleReads,
        nReads = as.integer(length(sampleReads)),
        Jmax = as.integer(10),
        pi = pi,
        pRgivenH1 = pRgivenH1L,
        pRgivenH2 = pRgivenH2L,
        pState = eHaps,
        eHaps = t(eHaps),
        alphaMat = t(alphaMat),
        transMatRate = transMatRate_t,
        maxDifferenceBetweenReads = as.double(1000),
        whatToReturn = as.integer(0),
        suppressOutput=as.integer(1),
        model=as.integer(9)
    )


})


test_that("can calculate fbd dosage", {

    nSNPs <- 10
    K <- 3
    KK <- K * K
    eHaps_t <- array(runif(K * nSNPs), c(K, nSNPs))
    gamma_t <- array(runif(KK * nSNPs), c(KK, nSNPs))
    grid <- 0:(nSNPs - 1)
    nGrids <- nSNPs ## since no grid

    out <- calculate_fbd_dosage(
        nGrids = nGrids,
        nSNPs = nSNPs,
        K = K,
        eHaps_t = eHaps_t,
        gamma_t = gamma_t,
        grid = grid
    )

    expect_equal(length(out$dosage), nSNPs)
    expect_equal(nrow(out$genProbs), nSNPs)
    expect_equal(ncol(out$genProbs), 3)
    expect_equal(sum(out$dosage == 0), 0)
    expect_equal(sum(out$genProbs == 0), 0)


})


test_that("can calculate fbd dosage using grid", {

    nSNPs <- 10
    nGrids <- 3
    K <- 3
    KK <- K * K
    eHaps_t <- array(runif(K * nSNPs), c(K, nSNPs))
    gamma_t <- array(runif(KK * nGrids), c(KK, nGrids))
    grid <- c(0, 0, 0, 1, 1, 1, 2, 2, 2, 2)

    out <- calculate_fbd_dosage(
        nGrids = nGrids,
        nSNPs = nSNPs,
        K = K,
        eHaps_t = eHaps_t,
        gamma_t = gamma_t,
        grid = grid
    )
    expect_equal(length(out$dosage), nSNPs)
    expect_equal(nrow(out$genProbs), nSNPs)
    expect_equal(ncol(out$genProbs), 3)
    expect_equal(sum(out$dosage == 0), 0)
    expect_equal(sum(out$genProbs == 0), 0)

})

