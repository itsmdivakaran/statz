# StatNext Review: Rakesh, November 2026

Feedback on StatNext v0.5.3 (branch `review/rakesh`): strengths, weaknesses, risks and recommendations. Project background, setup and architecture are covered in the README and `AGENTS.md` and are not repeated here.

## Contents

1. [Summary](#1-summary)
2. [Scope and Method](#2-scope-and-method)
3. [Appreciation](#3-appreciation)
4. [Strengths](#4-strengths)
5. [Weaknesses](#5-weaknesses)
6. [Risks](#6-risks)
7. [Recommendations](#7-recommendations)
8. [Feature Ideas](#8-feature-ideas)
9. [Comparison with Alternatives](#9-comparison-with-alternatives)
10. [Open Questions](#10-open-questions)
11. [Conclusion](#11-conclusion)
12. [Appendix](#12-appendix)

---

## 1. Summary

## 2. Scope and Method

## 3. Appreciation

StatNext is a rare thing: a statistics tool that treats reproducibility as the product rather than a feature. Showing the exact R code behind every result, and running that same code to produce it, is a simple idea that is hard to execute well. It has been executed well here.

**The technology choices are sound and deliberate.**
- Tauri 2 with a Rust shell keeps the app small and native on Windows, macOS and Linux, where an Electron build would have been heavy.
- R stays the single source of statistical truth. Nothing is reimplemented in the UI, so results match what an R user would get by hand.
- The R process is supervised carefully: JSON-RPC over stdio, clean cancellation that keeps the session alive, and crash recovery.
- Analyses are data, not code paths. A folder with a spec, a generator and a help page becomes a menu item and a dialog, and plugins use the same format. That design is why 56 analyses stay maintainable.
- Pinning R packages to a dated snapshot gives every user the same versions, which is the right call for a tool whose selling point is reproducible results.

**The engineering discipline is visible.**
- Results are checked against published reference values, and a test confirms the generated code reproduces the result when run on its own.
- Golden fixtures cover every module, and CI runs R, the UI against real R, and the Rust worker on Linux, macOS and Windows.
- Releases are automated across three operating systems, with a website and citation metadata (ORCIDs, Zenodo) in place from early on.

**The product thinking is thoughtful.**
- The "Which analysis should I use?" guide, the plain-language interpretation under each result, and the assumption checks help users get statistics right, not just get output.
- The optional AI assistant is built privacy-first: off by default, keys in the OS keychain, no data rows ever sent.
- The breadth is impressive for one application: Bayesian methods, survival, meta-analysis, mixed models, machine learning and time series.

Building and maintaining this across a Rust shell, a React app and an R engine, with six authors, takes sustained effort and care. The result is a credible, open alternative to commercial point-and-click statistics software.

## 4. Strengths

### 4.1 Architecture

### 4.2 Statistics and Reproducibility

### 4.3 User Experience

### 4.4 Installation and Distribution

### 4.5 Security and Privacy

### 4.6 Testing and Quality

### 4.7 Documentation

### 4.8 Extensibility

## 5. Weaknesses

### 5.1 Architecture

### 5.2 Statistics and Reproducibility

### 5.3 User Experience

### 5.4 Installation and Distribution

### 5.5 Security and Privacy

### 5.6 Testing and Quality

### 5.7 Documentation

### 5.8 Performance and Scalability

## 6. Risks

## 7. Recommendations

### 7.1 Quick Wins

### 7.2 Short Term

### 7.3 Long Term

## 8. Feature Ideas

## 9. Comparison with Alternatives

## 10. Open Questions

## 11. Conclusion

## 12. Appendix

### 12.1 Observations Log

### 12.2 Evidence

### 12.3 References
