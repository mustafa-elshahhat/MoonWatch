export {};

declare global {
  interface Window {
    tizen?: {
      tvinputdevice?: {
        registerKey(keyName: string): void;
        registerKeyBatch?(keyNames: string[]): void;
      };
    };
    webapis?: {
      avplay?: SamsungAvPlay;
    };
  }

  interface SamsungAvPlay {
    open(url: string): void;
    close(): void;
    prepareAsync(successCallback: () => void, errorCallback?: (error: unknown) => void): void;
    play(): void;
    pause(): void;
    stop(): void;
    seekTo(milliseconds: number, successCallback?: () => void, errorCallback?: (error: unknown) => void): void;
    getCurrentTime(): number;
    getDuration(): number;
    getState(): string;
    setDisplayRect(x: number, y: number, width: number, height: number): void;
    setDisplayMethod?(method: string): void;
    setStreamingProperty?(propertyName: string, propertyValue: string): void;
    setListener(listener: SamsungAvPlayListener): void;
  }

  interface SamsungAvPlayListener {
    onbufferingstart?: () => void;
    onbufferingprogress?: (percent: number) => void;
    onbufferingcomplete?: () => void;
    oncurrentplaytime?: (currentTime: number) => void;
    onevent?: (eventType: number, eventData: string) => void;
    onerror?: (eventType: unknown) => void;
    onsubtitlechange?: (duration: number, text: string, data3: number, data4: number) => void;
    onstreamcompleted?: () => void;
    ondrmevent?: (drmEvent: string, drmData: string) => void;
  }
}
