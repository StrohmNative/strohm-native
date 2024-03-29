package dev.strohmnative.viewmodels

import androidx.lifecycle.LiveData
import androidx.lifecycle.Transformations
import dev.strohmnative.*

open class KeyedArrayViewModel<EntryType>(
    initialData: List<EntryType>,
    propName: PropName,
    propPath: PropPath,
    private val instanceFactory: ConstructableFromDictionary<EntryType>
) : ViewModelBase<List<EntryType>>(initialData, propName, propPath) {
    var sorter: Comparator<EntryType>? = null
    var entries: LiveData<List<EntryType>> = Transformations.map(data) {
        data -> data as List<EntryType>
    }

    override fun propToData(prop: Prop): List<EntryType>? {
        if (prop.first != propName) { return null; }
        val m = prop.second as? Map<*, *> ?: return null
        val rawData = m.asMapOfType<PropName, Map<String, Any>>() ?: return null
        var data = rawData.values.mapNotNull(instanceFactory::createFromDict)
        return sorter?.let { data.sortedWith(it) } ?: data
    }
}
