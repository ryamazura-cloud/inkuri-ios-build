# Room and WorkManager instantiate these classes through their no-argument
# constructors. AGP 9 no longer implicitly keeps constructors for class-only
# consumer rules from the bundled Room and WorkManager versions.
-keep,allowoptimization class * extends androidx.room.RoomDatabase {
    public <init>();
}
-keep,allowoptimization class * extends androidx.work.InputMerger {
    public <init>();
}
