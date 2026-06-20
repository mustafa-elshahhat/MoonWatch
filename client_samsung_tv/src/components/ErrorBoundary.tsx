import { Component, type ErrorInfo, type ReactNode } from 'react';
import { ErrorState } from './ErrorState';
import { FocusBoundary } from './FocusBoundary';
import { Icon } from './Icon';

interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
  message: string;
}

/**
 * App-level error boundary (TV-002). A render/commit error in any screen would
 * otherwise white-screen the whole TV app with no recovery path on a device
 * that has no dev tools. This renders a polished recovery screen with focusable
 * "Return Home" and "Reload app" actions instead.
 *
 * Note: the try/catch inside App.tsx only catches errors thrown while building
 * the element object — React surfaces errors thrown during a child's
 * render/commit to an error boundary, which this provides.
 */
export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false, message: '' };

  static getDerivedStateFromError(error: unknown): ErrorBoundaryState {
    const message = error instanceof Error ? error.message : 'The app hit an unexpected error.';
    return { hasError: true, message };
  }

  componentDidCatch(error: unknown, info: ErrorInfo): void {
    // Surface the failure for diagnostics. Component stacks contain no
    // credentials or stream URLs, so this is safe to log.
    console.error('[MoonWatch] Uncaught render error', error, info.componentStack);
  }

  private handleHome = (): void => {
    // Clearing the error re-renders the children, remounting the app fresh at
    // its initial screen (Home when configured).
    this.setState({ hasError: false, message: '' });
  };

  private handleReload = (): void => {
    window.location.reload();
  };

  render(): ReactNode {
    if (this.state.hasError) {
      return (
        <FocusBoundary className="screen screen--center">
          <ErrorState
            icon={<Icon name="alert" size={30} />}
            title="Something went wrong"
            message={this.state.message || 'The app hit an unexpected error. Return home or reload to continue.'}
            actionLabel="Reload app"
            onAction={this.handleReload}
            secondaryLabel="Return Home"
            onSecondary={this.handleHome}
          />
        </FocusBoundary>
      );
    }
    return this.props.children;
  }
}
