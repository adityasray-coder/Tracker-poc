/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React, {useState} from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
  Pressable,
} from 'react-native';

import {Colors} from 'react-native/Libraries/NewAppScreen';

const TAB_LABELS = ['Home', 'Explore', 'Saved', 'Profile'];
const CARD_WIDTH = 160;
const CARD_MARGIN = 12;

// Sample data for the horizontal list
const LIST_ITEMS = Array.from({length: 12}, (_, i) => ({
  id: String(i + 1),
  title: `Item ${i + 1}`,
  subtitle: `Description for item ${i + 1}`,
}));

function App(): JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  const [activeTab, setActiveTab] = useState(0);

  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };
  const surfaceStyle = {
    backgroundColor: isDarkMode ? Colors.black : Colors.white,
  };
  const textColor = isDarkMode ? Colors.white : Colors.black;
  const mutedColor = isDarkMode ? Colors.light : Colors.dark;
  const tabActiveBg = isDarkMode ? Colors.light : Colors.dark;
  const tabInactiveBg = 'transparent';
  const tabActiveText = isDarkMode ? Colors.black : Colors.white;
  const tabInactiveText = mutedColor;

  return (
    <SafeAreaView style={[styles.container, backgroundStyle]}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={backgroundStyle.backgroundColor}
      />

      {/* Top tabs */}
      <View style={[styles.tabBar, surfaceStyle]}>
        {TAB_LABELS.map((label, index) => (
          <Pressable
            key={label}
            style={[
              styles.tab,
              activeTab === index && {
                backgroundColor: tabActiveBg,
              },
            ]}
            onPress={() => setActiveTab(index)}>
            <Text
              style={[
                styles.tabLabel,
                {
                  color: activeTab === index ? tabActiveText : tabInactiveText,
                },
              ]}>
              {label}
            </Text>
          </Pressable>
        ))}
      </View>

      {/* Horizontally scrollable list */}
      <View style={[styles.body, backgroundStyle]}>
        <Text style={[styles.sectionTitle, {color: textColor}]}>
          {TAB_LABELS[activeTab]}
        </Text>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.horizontalListContent}
          style={styles.horizontalList}>
          {LIST_ITEMS.map(item => (
            <View
              key={item.id}
              style={[styles.card, surfaceStyle, {borderColor: mutedColor}]}>
              <View style={[styles.cardThumb, {backgroundColor: mutedColor}]} />
              <Text style={[styles.cardTitle, {color: textColor}]} numberOfLines={1}>
                {item.title}
              </Text>
              <Text style={[styles.cardSubtitle, {color: mutedColor}]} numberOfLines={2}>
                {item.subtitle}
              </Text>
            </View>
          ))}
        </ScrollView>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  tabBar: {
    flexDirection: 'row',
    paddingHorizontal: 8,
    paddingVertical: 8,
    gap: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(0,0,0,0.1)',
  },
  tab: {
    flex: 1,
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabLabel: {
    fontSize: 14,
    fontWeight: '600',
  },
  body: {
    flex: 1,
    paddingTop: 16,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '600',
    paddingHorizontal: 20,
    marginBottom: 12,
  },
  horizontalList: {
    flexGrow: 0,
  },
  horizontalListContent: {
    paddingHorizontal: 20,
    paddingBottom: 24,
  },
  card: {
    width: CARD_WIDTH,
    marginRight: CARD_MARGIN,
    padding: 12,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
  },
  cardThumb: {
    width: '100%',
    aspectRatio: 1,
    borderRadius: 8,
    marginBottom: 8,
    opacity: 0.3,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  cardSubtitle: {
    fontSize: 12,
  },
});

export default App;
