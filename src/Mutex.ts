/**
 * @license
 * Copyright 2025 Google Inc.
 * SPDX-License-Identifier: Apache-2.0
 */

export class Mutex {
  static Guard = class Guard {
    #mutex: Mutex;
    #onRelease?: () => void;
    #released = false;
    constructor(mutex: Mutex, onRelease?: () => void) {
      this.#mutex = mutex;
      this.#onRelease = onRelease;
    }
    dispose(): void {
      if (this.#released) {
        return;
      }
      this.#released = true;
      this.#onRelease?.();
      return this.#mutex.release();
    }
  };

  #maxConcurrency: number;
  #active = 0;
  #acquirers: Array<() => void> = [];

  constructor(maxConcurrency = 1) {
    this.#maxConcurrency = Math.max(1, Math.floor(maxConcurrency));
  }

  // This is FIFO.
  async acquire(
    onRelease?: () => void,
  ): Promise<InstanceType<typeof Mutex.Guard>> {
    if (this.#active < this.#maxConcurrency) {
      this.#active += 1;
      return new Mutex.Guard(this, onRelease);
    }
    const {resolve, promise} = Promise.withResolvers<void>();
    this.#acquirers.push(resolve);
    await promise;
    return new Mutex.Guard(this, onRelease);
  }

  release(): void {
    const resolve = this.#acquirers.shift();
    if (!resolve) {
      this.#active = Math.max(0, this.#active - 1);
      return;
    }
    // Hand the same concurrency slot to the next waiter.
    resolve();
  }
}
