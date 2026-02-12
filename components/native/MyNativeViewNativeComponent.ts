/**
 * Native UI component that uses SwiftUI .onAppear and emits onNativeAppear to JS.
 * Use with Fabric/New Architecture; falls back to Paper via requireNativeComponent.
 */

import type {ViewProps} from 'react-native';
import type {DirectEventHandler} from 'react-native/Libraries/Types/CodegenTypes';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

export interface NativeProps extends ViewProps {
  onNativeAppear?: DirectEventHandler<null>;
}

export default codegenNativeComponent<NativeProps>('MyNativeView');
