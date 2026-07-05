//! The realiser seam (bd-bec201, nlir-wasm P0): the **effectful** half of
//! realisation behind an injectable async trait, so ONE evaluator serves both
//! the native CLI and the browser (WASM).
//!
//! - **Native** = [`NativeRealiser`]: the existing HTTP / `bash` subprocess
//!   backends ([`crate::llm::run_llm`] / [`crate::llm::run_operator_command`]),
//!   wrapped as immediately-ready futures. Behaviour is identical to the direct
//!   pre-seam calls.
//! - **WASM** (P1/P3/P6) = a JS-callback realiser: `llm` → `fetch(base_url)` or
//!   an on-device model; `command` → the wasm-sh worker.
//!
//! Deterministic realisation (`reduce:` / `template:` / `join:`, [`crate::realise`])
//! is pure and does **not** pass through this seam. The seam is at
//! *realisation*, not *scheduling*: the native evaluator keeps its
//! `thread::scope` operand parallelism unchanged.

use std::future::Future;
use std::pin::Pin;

use crate::llm::{LlmCall, RealiseError};

/// A boxed future returned by [`Realiser`] methods. Intentionally **not**
/// `Send`: browser futures (`fetch`) are single-threaded, and the native
/// realiser resolves synchronously, so a thread-safe bound would only exclude
/// the WASM host this seam exists to serve.
pub type RealiseFuture<'a> = Pin<Box<dyn Future<Output = Result<String, RealiseError>> + 'a>>;

/// The injectable effectful-realisation backend.
///
/// The evaluator assembles each effectful operator into either an [`LlmCall`]
/// (model + prompt vars, via [`crate::llm::assemble_llm`]) or an operator
/// `command:` snippet with rendered operands, then calls the host realiser.
/// Deterministic operators never reach here.
///
/// This trait is the **only** new surface the WASM crate wires JS callbacks
/// into; native code uses [`NativeRealiser`].
pub trait Realiser {
    /// Realise an assembled llm operator (model + prompt already resolved).
    fn llm<'a>(&'a self, call: &'a LlmCall) -> RealiseFuture<'a>;
    /// Realise an operator `command:` snippet with rendered `operands`.
    fn command<'a>(&'a self, command: &'a str, operands: &'a [String]) -> RealiseFuture<'a>;
}

/// The native realiser: the existing HTTP / `bash` backends wrapped as
/// immediately-ready futures. Behaviour is identical to the pre-seam direct
/// calls; the futures complete on the FIRST poll (see [`block_on_ready`]).
///
/// Native-only: its bodies use `std::process::Command` / HTTP, which do not
/// build on `wasm32-unknown-unknown` — a WASM host supplies its own [`Realiser`].
#[cfg(feature = "native")]
#[derive(Debug, Default, Clone, Copy)]
pub struct NativeRealiser;

#[cfg(feature = "native")]
impl Realiser for NativeRealiser {
    fn llm<'a>(&'a self, call: &'a LlmCall) -> RealiseFuture<'a> {
        Box::pin(async move { crate::llm::run_llm(call) })
    }

    fn command<'a>(&'a self, command: &'a str, operands: &'a [String]) -> RealiseFuture<'a> {
        Box::pin(async move { crate::llm::run_operator_command(command, operands) })
    }
}

/// Drive an immediately-ready future to completion with a no-op waker.
///
/// [`NativeRealiser`] wraps blocking calls in async blocks that complete on the
/// FIRST poll, so this needs no async runtime and never busy-loops. It lets the
/// synchronous native evaluator (which keeps its `thread::scope` operand
/// parallelism — the seam is at realisation, not scheduling) drive the async
/// [`Realiser`] without pulling in an executor dependency.
///
/// # Panics
/// Panics if `fut` is not ready on the first poll. A genuinely pending future
/// (e.g. a real network fetch) must be driven by an async runtime instead — the
/// browser drives the async eval entry via `wasm-bindgen-futures`.
pub fn block_on_ready<T>(fut: impl Future<Output = T>) -> T {
    use std::task::{Context, Poll};

    let mut fut = Box::pin(fut);
    let waker = std::task::Waker::noop();
    let mut cx = Context::from_waker(waker);
    match fut.as_mut().poll(&mut cx) {
        Poll::Ready(value) => value,
        Poll::Pending => {
            panic!("block_on_ready: native realiser future was not ready on the first poll")
        }
    }
}

#[cfg(all(test, feature = "native"))]
mod tests {
    use super::*;

    #[test]
    fn block_on_ready_returns_a_ready_value() {
        assert_eq!(block_on_ready(async { 41 + 1 }), 42);
    }

    #[test]
    fn native_realiser_command_shells_out() {
        let realiser = NativeRealiser;
        // The operator `command:` bash snippet; NLIR_ARGS is prepended for it.
        let out = block_on_ready(
            realiser.command("printf '%s' \"${NLIR_ARGS[0]}\"", &["hello".to_owned()]),
        )
        .expect("command realisation");
        assert_eq!(out, "hello");
    }
}
